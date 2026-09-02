# API Contract — Grocery Store App

Backend: FastAPI + PostgreSQL (SQLAlchemy 2.0, Alembic, JWT auth, Pydantic v2).
Frontend: Flutter (Provider state management, dio for HTTP, flutter_secure_storage for token).
Base URL (dev): `http://<host>:8000/api/v1`

All authenticated requests send `Authorization: Bearer <jwt>`.

## Data model (SQLAlchemy models, PostgreSQL)

Every business table carries `store_id` from day one so the schema scales to
multiple stores later without migration surgery, even though the MVP UI only
ever operates against one seeded store.

```
stores
  id (pk), name, code (short prefix e.g. "ORD"), whatsapp_number (E.164, e.g. "919999999999"),
  address, logo_url, order_sequence (int, default 0, incremented per order),
  is_active (bool), created_at, updated_at

users
  id (pk), store_id (fk stores, nullable for now, set on register), name, email (unique, nullable),
  phone (unique, 10-digit Indian mobile, no country code), password_hash (nullable —
  only the owner/employee roles use password login; customers use phone+OTP),
  role (enum: "owner" | "customer" | "employee"), is_active (bool),
  address_line1, town, district, state, pincode (all nullable at the DB level,
  mandatory at the API level for customer registration — owner/employee don't use them),
  otp_failed_attempts (int, default 0), otp_locked_until (datetime, nullable —
  set when otp_failed_attempts hits otp_max_attempts, see OTP rules below),
  created_at, updated_at

otp_codes
  id (pk), user_id (fk users), phone, code (4-digit str), purpose (str, default "login"),
  expires_at (datetime), consumed (bool, default false), created_at

categories
  id (pk), store_id (fk), name, sort_order (int), is_active (bool), created_at, updated_at

products
  id (pk), store_id (fk), category_id (fk categories), name, name_te (nullable — Telugu
  name shown alongside the English name in the app), description (nullable),
  image_url (nullable), price (numeric(10,2)), unit (str, e.g. "kg" | "pack" | "pc", default "pc"),
  is_available (bool, default true), created_at, updated_at

orders
  id (pk), store_id (fk), order_number (unique str, e.g. "ORD-000123"),
  customer_id (fk users), customer_name (snapshot), customer_phone (snapshot),
  status (enum: "pending" | "confirmed" | "preparing" | "ready" | "completed" | "cancelled"),
  notes (text, nullable), subtotal (numeric), total_amount (numeric),
  order_date (datetime), updated_at

order_items
  id (pk), order_id (fk), product_id (fk products), product_name (snapshot),
  product_price (snapshot numeric), quantity (int), line_total (numeric)

order_status_history
  id (pk), order_id (fk), status, changed_at, changed_by_user_id (fk users, nullable)

notifications
  id (pk), store_id (fk), order_id (fk, nullable), type (str, e.g. "new_order"),
  message (text), is_read (bool, default false), created_at

-- Reserved for later phases, not built in MVP but shape reserved:
-- payments(id, order_id, amount, method, status, transaction_ref, paid_at)
-- deliveries(id, order_id, rider_name, status, eta, delivered_at)
-- reports are computed from orders/order_items, no dedicated table needed yet
```

Order number generation: increment `stores.order_sequence` in a single
transaction (row-level lock via `SELECT ... FOR UPDATE`), format as
`f"{store.code}-{sequence:06d}"` e.g. `ORD-000123`.

## Auth

Two different login mechanisms by role:

- **Owner** (and any future employee): phone + password, via `POST /auth/login`.
- **Customer**: phone + OTP only — customers never set a password. Registration
  collects their profile; login is a separate two-step OTP exchange.

### Registration (customer)

- `POST /auth/register` — body:
  ```json
  {
    "name": "Full Name",
    "phone": "9876543210",
    "email": "optional@example.com",
    "address_line1": "12 MG Road",
    "town": "Whitefield",
    "district": "Bengaluru Urban",
    "state": "Karnataka",
    "pincode": "560066"
  }
  ```
  `phone` must match `^[6-9]\d{9}$` (10-digit Indian mobile, no country code,
  no leading 0). `pincode` must match `^[1-9]\d{5}$`. Every field is mandatory
  except `email`. Creates a `customer` user (no password) scoped to the single
  seeded store. Response: `{message, user}` — **no token**; the app shows the
  success message then sends the customer to the OTP login flow.
  400 if the phone (or email, if given) is already registered.

### Login

- **Owner**: `POST /auth/login` — body `{phone, password}` → `{token, user}`.
  401 if the account has no `password_hash` set (i.e. it's a customer).
- **Customer** — two calls:
  1. `POST /auth/otp/request` — body `{phone}`. 404 if the phone isn't
     registered. 429 if currently locked out (see OTP rules). On success,
     generates a 4-digit code, stores it with a 2-minute expiry, and returns:
     ```json
     { "message": "OTP sent to your mobile number.", "expires_in_seconds": 120, "dev_otp": "0492" }
     ```
     `dev_otp` is **only present in dev mode** (no real SMS provider wired up
     yet — see `app/otp_service.py`); the app should show it to the user only
     when present, e.g. via a "Dev mode: your OTP is 0492" banner/snackbar.
     In production mode this field is `null` and the code only goes out via SMS.
  2. `POST /auth/otp/verify` — body `{phone, code}` → `{token, user}` on
     success. 400 "OTP has expired" if no live code exists. 400 "Incorrect
     OTP. N attempt(s) remaining." on a wrong code (doesn't consume the
     code — the same OTP can be retried until it expires or the attempt
     limit is hit). 429 once the attempt limit is hit, with a lockout message.

### OTP rules (`app/config.py`, mirror in the Dart OTP screen's countdown/lockout UI)

- Code length: **4 digits**.
- Expiry: **2 minutes** (120s) from generation. `otp/request` can be called
  again before expiry to get a fresh code (this replaces — doesn't stack with
  — any previous unconsumed code for that phone, since `otp/verify` always
  checks the most recently created one).
- Wrong-attempt limit: **3 consecutive wrong codes** → the phone is locked
  out of both `otp/request` and `otp/verify` for **10 minutes**
  (`otp_locked_until` on the user row). The counter resets to 0 on a
  successful verify, and also resets (fresh 3 attempts) once a lockout expires.

`GET /auth/me` — returns current user (works for both owner and customer).

JWT payload: `{sub: user_id, role, store_id}`. Expiry 30 days (mobile app,
no refresh-token flow needed for MVP — re-login on expiry).

Password hashing: passlib bcrypt. OTP codes are stored in plaintext (they're
single-use, 2-minute-lived, and 3-attempt-limited — not sensitive enough to
warrant hashing, unlike passwords).

## Categories

- `GET /categories` — public read, list active categories ordered by `sort_order`.
- `POST /categories` — owner only. `{name, sort_order?}`
- `PUT /categories/{id}` — owner only.
- `DELETE /categories/{id}` — owner only. Soft delete (`is_active=false`) if
  products reference it, hard delete otherwise.

## Products

- `GET /products?category_id=&search=&available_only=true` — public read.
  `search` matches `name` case-insensitively.
- `GET /products/{id}` — public read.
- `POST /products` — owner only, `multipart/form-data`: `name, name_te?, category_id,
  price, unit?, description?, is_available?, image` (file, optional).
- `PUT /products/{id}` — owner only, same multipart shape, all fields optional.
- `PATCH /products/{id}/availability` — owner only. `{is_available: bool}`.
  (Dedicated endpoint because toggling availability is the single most
  frequent owner action and shouldn't require a full form re-submit.)
- `DELETE /products/{id}` — owner only.
- Uploaded images are served statically from `/static/products/<filename>`;
  `image_url` in responses is the full path the app can load directly.

## Orders

- `POST /orders` — customer only. Body:
  ```json
  {
    "items": [{"product_id": 1, "quantity": 2}],
    "notes": "Ring the bell twice"
  }
  ```
  Server recomputes prices from the DB (never trusts client-sent prices),
  creates `order` + `order_items` + `order_status_history` (status=pending)
  + a `notifications` row (type=new_order) for the owner. Response:
  ```json
  {
    "order": { ...full order incl items, order_number, total_amount... },
    "whatsapp_message": "🛒 New Order - ORD-000123\n...",
    "whatsapp_url": "https://wa.me/919999999999?text=..."
  }
  ```
  The app opens `whatsapp_url` via `url_launcher` right after order creation.
- `GET /orders` — customer: own orders only. Owner: all orders, optional
  `?status=pending`. Newest first.
- `GET /orders/{id}` — full order with items + status history. Owner can view
  any order in their store; customer only their own (403 otherwise).
- `PATCH /orders/{id}/status` — owner only. `{status: "confirmed"}`. Appends
  to `order_status_history`. Valid forward transitions only (pending →
  confirmed → preparing → ready → completed; cancelled reachable from any
  non-terminal state) — invalid transition returns 400.

Receipt PDF generation happens **client-side in Flutter** (a single shared
`ReceiptPdfBuilder` widget/service used both by the customer's "download
receipt" action and the owner's "print receipt" action), built from the
`GET /orders/{id}` response — no backend PDF dependency needed.

## Notifications (owner)

- `GET /notifications/unread-count` — owner only. `{count: int}`. Polled by
  the Flutter app every ~15s while the owner is on the orders screen to
  drive a badge (no push infra in MVP; FCM is a natural later add-on since
  swapping this poll for push doesn't change the data model).
- `POST /notifications/{id}/read` — owner only.
- `POST /notifications/read-all` — owner only.

## Standard error shape

```json
{ "detail": "human readable message" }
```
404/403/400/422 used conventionally. FastAPI's default validation error
shape is preserved for 422s.

## Enums (shared source of truth — mirror exactly in Dart)

```
UserRole:   owner | customer | employee
OrderStatus: pending | confirmed | preparing | ready | completed | cancelled
```
