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

class RevalidatingStaticFiles(StaticFiles):
    """Product photos get overwritten in place at the same URL whenever an
    owner re-uploads one or a catalog image is regenerated. Browsers
    heuristically cache static files for a long time from just a
    Last-Modified header (no Cache-Control), so a tab that already loaded a
    product once can keep showing the old bytes for that URL indefinitely
    even after the file on disk changes. Cache-Control: no-cache forces a
    conditional GET (If-Modified-Since) on every load instead of trusting
    that heuristic — cheap (a 304 when the file hasn't changed) and
    guarantees a changed file is never stuck stale in the browser cache.
    """

    def file_response(self, *args, **kwargs):
        response = super().file_response(*args, **kwargs)
        response.headers["Cache-Control"] = "no-cache"
        return response


app.mount("/static", RevalidatingStaticFiles(directory=settings.static_dir), name="static")

api_prefix = "/api/v1"
app.include_router(auth.router, prefix=api_prefix)
app.include_router(categories.router, prefix=api_prefix)
app.include_router(products.router, prefix=api_prefix)
app.include_router(orders.router, prefix=api_prefix)
app.include_router(notifications.router, prefix=api_prefix)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
