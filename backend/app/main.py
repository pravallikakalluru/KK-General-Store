from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.routers import auth, categories, notifications, orders, products

settings = get_settings()

Path(settings.static_dir).mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Grocery Store API", version="1.0.0")

# Mobile app talks to this API directly with a bearer token, not cookies,
# so a permissive CORS policy carries no CSRF risk and keeps local dev
# (emulator, physical device, web preview) friction-free.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=settings.static_dir), name="static")

api_prefix = "/api/v1"
app.include_router(auth.router, prefix=api_prefix)
app.include_router(categories.router, prefix=api_prefix)
app.include_router(products.router, prefix=api_prefix)
app.include_router(orders.router, prefix=api_prefix)
app.include_router(notifications.router, prefix=api_prefix)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
