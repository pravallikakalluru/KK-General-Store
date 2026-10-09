from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_owner
from app.image_storage import delete_product_image, save_product_image
from app.models import Product, User
from app.schemas import AvailabilityUpdate, ProductOut
from app.store_utils import get_default_store

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=list[ProductOut])
def list_products(
    category_id: int | None = None,
    search: str | None = None,
    available_only: bool = False,
    db: Session = Depends(get_db),
) -> list[Product]:
    store = get_default_store(db)
    stmt = select(Product).where(Product.store_id == store.id)

    if category_id is not None:
        stmt = stmt.where(Product.category_id == category_id)
    if search:
        # Also check the Telugu name and owner-maintained aliases (see
        # Product.search_aliases) - not just the English name - so this
        # stays consistent with the app's own multilingual search matching
        # (mobile/lib/utils/search_matcher.dart) if it's ever used from here.
        term = f"%{search}%"
        stmt = stmt.where(
            or_(
                Product.name.ilike(term),
                Product.name_te.ilike(term),
                Product.search_aliases.ilike(term),
            )
        )
    if available_only:
        stmt = stmt.where(Product.is_available.is_(True))

    stmt = stmt.order_by(Product.name)
    return list(db.scalars(stmt))


@router.get("/{product_id}", response_model=ProductOut)
def get_product(product_id: int, db: Session = Depends(get_db)) -> Product:
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    return product


@router.post("", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
def create_product(
    name: str = Form(...),
    name_te: str | None = Form(None),
    search_aliases: str | None = Form(None),
    category_id: int = Form(...),
    price: float = Form(...),
    unit: str = Form("pc"),
    description: str | None = Form(None),
    is_available: bool = Form(True),
    image: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> Product:
    store = get_default_store(db)

    image_url = save_product_image(image) if image is not None and image.filename else None

    product = Product(
        store_id=store.id,
        category_id=category_id,
        name=name,
        name_te=name_te,
        search_aliases=search_aliases,
        description=description,
        image_url=image_url,
        price=price,
        unit=unit,
        is_available=is_available,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.put("/{product_id}", response_model=ProductOut)
def update_product(
    product_id: int,
    name: str | None = Form(None),
    name_te: str | None = Form(None),
    search_aliases: str | None = Form(None),
    category_id: int | None = Form(None),
    price: float | None = Form(None),
    unit: str | None = Form(None),
    description: str | None = Form(None),
    is_available: bool | None = Form(None),
    image: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> Product:
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    if name is not None:
        product.name = name
    if name_te is not None:
        product.name_te = name_te
    if search_aliases is not None:
        product.search_aliases = search_aliases
    if category_id is not None:
        product.category_id = category_id
    if price is not None:
        product.price = price
    if unit is not None:
        product.unit = unit
    if description is not None:
        product.description = description
    if is_available is not None:
        product.is_available = is_available
    if image is not None and image.filename:
        delete_product_image(product.image_url)
        product.image_url = save_product_image(image)

    db.commit()
    db.refresh(product)
    return product


@router.patch("/{product_id}/availability", response_model=ProductOut)
def update_availability(
    product_id: int,
    payload: AvailabilityUpdate,
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> Product:
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    product.is_available = payload.is_available
    db.commit()
    db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    _owner: User = Depends(require_owner),
) -> None:
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    delete_product_image(product.image_url)
    db.delete(product)
    db.commit()
