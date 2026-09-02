from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Store


def get_default_store(db: Session) -> Store:
    """Return the single active store.

    The schema supports many stores (every business table carries
    store_id), but the MVP app only ever operates against one. This is the
    single seam to replace once there's real multi-store routing (e.g. a
    store_id path param or subdomain) - nothing else needs to change.
    """
    store = db.scalar(select(Store).where(Store.is_active.is_(True)).order_by(Store.id))
    if store is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No store configured. Run the seed script first.")
    return store
