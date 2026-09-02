from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_owner
from app.models import Notification, User
from app.schemas import UnreadCountOut
from app.store_utils import get_default_store

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/unread-count", response_model=UnreadCountOut)
def unread_count(db: Session = Depends(get_db), _owner: User = Depends(require_owner)) -> UnreadCountOut:
    store = get_default_store(db)
    count = db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.store_id == store.id, Notification.is_read.is_(False))
    )
    return UnreadCountOut(count=count or 0)


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> None:
    notification = db.get(Notification, notification_id)
    if notification is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Notification not found")
    notification.is_read = True
    db.commit()


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
def mark_all_read(db: Session = Depends(get_db), _owner: User = Depends(require_owner)) -> None:
    store = get_default_store(db)
    db.execute(
        Notification.__table__.update()
        .where(Notification.store_id == store.id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    db.commit()
