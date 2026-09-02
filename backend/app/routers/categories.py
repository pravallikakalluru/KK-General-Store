from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_owner
from app.models import Category, Product, User
from app.schemas import CategoryCreate, CategoryOut, CategoryUpdate
from app.store_utils import get_default_store

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
def list_categories(db: Session = Depends(get_db)) -> list[Category]:
    store = get_default_store(db)
    stmt = (
        select(Category)
        .where(Category.store_id == store.id, Category.is_active.is_(True))
        .order_by(Category.sort_order, Category.name)
    )
    return list(db.scalars(stmt))


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def create_category(
    payload: CategoryCreate,
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> Category:
    store = get_default_store(db)
    category = Category(store_id=store.id, name=payload.name, sort_order=payload.sort_order)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.put("/{category_id}", response_model=CategoryOut)
def update_category(
    category_id: int,
    payload: CategoryUpdate,
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> Category:
    category = db.get(Category, category_id)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Category not found")

    if payload.name is not None:
        category.name = payload.name
    if payload.sort_order is not None:
        category.sort_order = payload.sort_order
    if payload.is_active is not None:
        category.is_active = payload.is_active

    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(
    category_id: int,
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> None:
    category = db.get(Category, category_id)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Category not found")

    has_products = db.scalar(select(Product.id).where(Product.category_id == category_id).limit(1))
    if has_products is not None:
        category.is_active = False
        db.commit()
        return

    db.delete(category)
    db.commit()
