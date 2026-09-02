# Grocery Store API (backend)

FastAPI + PostgreSQL backend for the grocery ordering app. Full endpoint
reference: [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md).

## First-time setup

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

copy .env.example .env
# edit .env: set DATABASE_URL to a real database/user/password you've created,
# and change JWT_SECRET_KEY to a random value.
```

Create the database and app user in PostgreSQL (run once, using `psql` or
pgAdmin, as the `postgres` superuser):

```sql
CREATE USER grocery_app WITH PASSWORD 'changeme';
CREATE DATABASE grocery_app OWNER grocery_app;
```

Apply the schema and seed sample data:

```powershell
alembic upgrade head
python seed.py
```

`seed.py` prints the owner login it created (phone + password from your
`.env`) and populates a full bilingual (English + Telugu) catalog — fruits,
vegetables, pooja/temple items, cleaning & household, grains & pulses,
cooking essentials, spices, instant foods, dairy. It's idempotent — safe to
re-run any time after editing the `CATALOG` dict in `seed.py`; it only
inserts what's missing and refreshes price/unit/name_te on existing rows.

Generate a picture for every product that doesn't have one yet (illustrative
icon cards, not real photography — the owner can replace any of them with a
real photo later via Edit Product in the app):

```powershell
python generate_product_images.py
```

This writes to `static/products/`, which is gitignored (regeneratable, not
source) — run it again after `seed.py` whenever new products are added.

## Running

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Interactive API docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health
- From a physical Android device or emulator, point the Flutter app's API
  base URL at your machine's LAN IP (not `localhost`) — Android emulators
  use `10.0.2.2` to reach the host machine's `localhost`.
- Customers log in with phone + OTP, not a password (see `docs/API_CONTRACT.md`
  "Login"). No SMS provider is wired up yet (`otp_dev_mode=True` in
  `app/config.py`), so `POST /auth/otp/request` returns the generated code
  directly in the response (`dev_otp`) instead of texting it — the app shows
  this in a "Dev mode" banner. The owner still logs in with phone + password
  (seeded credentials printed by `seed.py`).

## Schema changes

This project uses Alembic migrations, not `create_all()`, precisely because
the schema is meant to grow (multi-store, payments, delivery tracking,
employees, reports, AI features — see the reserved-table notes at the
bottom of `docs/API_CONTRACT.md`). After changing a model in `app/models.py`:

```powershell
alembic revision --autogenerate -m "describe the change"
alembic upgrade head
```
