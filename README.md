# Grocery Store App

Mobile-first grocery/general store ordering app with two roles: **Owner**
(manages categories, products, and incoming orders) and **Customer**
(browses, orders, and submits via WhatsApp).

- `backend/` — FastAPI + PostgreSQL REST API. See [`backend/README.md`](backend/README.md).
- `mobile/` — Flutter Android app. See [`mobile/README.md`](mobile/README.md).
- `docs/API_CONTRACT.md` — the single source of truth both sides are built against: data model, every endpoint, request/response shapes, and enums.

## Why this stack

- **Flutter** for the app: one Dart codebase producing a real native Android
  app, with reusable widgets (product cards, cart tiles, status badges)
  matching the "reusable components" requirement directly.
- **FastAPI + PostgreSQL** for the backend: a relational schema is a natural
  fit for orders/order-items/payments joins and reporting later, and every
  table already carries `store_id` so adding stores, employees, payments,
  delivery tracking, and reports later is additive — no redesign.
- **WhatsApp via `wa.me` deep link** for order submission: works immediately
  with no Meta Business API approval process or per-message cost. The order
  is saved to the database first (so it's never lost even if the customer
  doesn't hit send), then WhatsApp opens pre-filled for the customer to
  confirm and send.
- Order/owner receipts are generated **client-side in Flutter** from the
  order JSON (one shared PDF builder used by both "customer downloads
  receipt" and "owner prints receipt"), so the backend doesn't need a PDF
  dependency at all.

## Getting the whole thing running

1. **Backend**: follow [`backend/README.md`](backend/README.md) — install
   PostgreSQL, create the database, run migrations, seed sample data, start
   `uvicorn`. Note the owner login `seed.py` prints out.
2. **Mobile**: follow [`mobile/README.md`](mobile/README.md) — install the
   Flutter SDK + Android SDK, generate the native `android/` folder, point
   the app's API base URL at your backend, `flutter run`.
3. Log in as the owner (seeded phone/password) to add real categories,
   products, and product photos before customers start ordering.

## What's deliberately out of scope for v1 (and how to add it later)

The schema and contract reserve room for these without breaking anything
already built — see the bottom of `docs/API_CONTRACT.md`:

- **Multiple stores** — every table already has `store_id`; swap
  `get_default_store()` in the backend for real per-store routing.
- **Employees** — `users.role` already has an `employee` value reserved.
- **Payments** — add a `payments` table keyed by `order_id`.
- **Delivery tracking** — add a `deliveries` table keyed by `order_id`.
- **Reports** — computable straight from `orders`/`order_items`, no schema
  change needed, just new read endpoints.
- **AI features** (e.g. reorder suggestions, demand forecasting) — layer on
  top of the existing `orders`/`order_items` history.
- **Push notifications for new orders** — the owner app currently polls
  `GET /notifications/unread-count`; swap for FCM without changing the data
  model.
