from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.database import get_db
from app.deps import get_current_user, require_customer, require_owner
from app.models import (
    ORDER_STATUS_TRANSITIONS,
    Notification,
    Order,
    OrderItem,
    OrderStatus,
    OrderStatusHistory,
    Product,
    Store,
    User,
    UserRole,
)
from app.schemas import OrderCreateRequest, OrderCreateResponse, OrderOut, OrderStatusUpdateRequest
from app.store_utils import get_default_store

router = APIRouter(prefix="/orders", tags=["orders"])


def _order_query():
    return select(Order).options(
        selectinload(Order.items), selectinload(Order.status_history)
    )


def _next_order_number(db: Session, store: Store) -> str:
    # Lock the store row so two concurrent checkouts can't be handed the
    # same sequence number.
    locked_store = db.execute(
        select(Store).where(Store.id == store.id).with_for_update()
    ).scalar_one()
    locked_store.order_sequence += 1
    db.flush()
    return f"{locked_store.code}-{locked_store.order_sequence:06d}"


def _build_whatsapp_message(order: Order) -> str:
    lines = [
        f"New Order - {order.order_number}",
        f"Customer: {order.customer_name} ({order.customer_phone})",
        "",
        "Items:",
    ]
    for index, item in enumerate(order.items, start=1):
        lines.append(
            f"{index}. {item.product_name} ({item.unit}) x{item.quantity} = Rs.{item.line_total}"
        )

    lines += ["", f"Subtotal: Rs.{order.subtotal}", f"Total: Rs.{order.total_amount}"]

    if order.notes:
        lines += ["", f"Notes: {order.notes}"]

    lines += ["", f"Order Date: {order.order_date:%d %b %Y, %I:%M %p}"]
    return "\n".join(lines)


@router.post("", response_model=OrderCreateResponse, status_code=status.HTTP_201_CREATED)
def create_order(
    payload: OrderCreateRequest,
    db: Session = Depends(get_db),
    customer: User = Depends(require_customer),
) -> OrderCreateResponse:
    store = get_default_store(db)

    product_ids = [item.product_id for item in payload.items]
    products = {p.id: p for p in db.scalars(select(Product).where(Product.id.in_(product_ids)))}

    order_items: list[OrderItem] = []
    subtotal = 0.0
    for requested in payload.items:
        product = products.get(requested.product_id)
        if product is None:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Product {requested.product_id} not found")
        if not product.is_available:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"'{product.name}' is currently unavailable")

        line_total = round(float(product.price) * requested.quantity, 2)
        subtotal += line_total
        order_items.append(
            OrderItem(
                product_id=product.id,
                product_name=product.name,
                product_name_te=product.name_te,
                product_price=product.price,
                unit=product.unit,
                quantity=requested.quantity,
                line_total=line_total,
            )
        )

    subtotal = round(subtotal, 2)
    order_number = _next_order_number(db, store)

    order = Order(
        store_id=store.id,
        order_number=order_number,
        customer_id=customer.id,
        customer_name=customer.name,
        customer_phone=customer.phone,
        status=OrderStatus.PENDING,
        notes=payload.notes,
        subtotal=subtotal,
        total_amount=subtotal,
        items=order_items,
    )
    db.add(order)
    db.flush()

    db.add(OrderStatusHistory(order_id=order.id, status=OrderStatus.PENDING, changed_by_user_id=customer.id))
    db.add(
        Notification(
            store_id=store.id,
            order_id=order.id,
            type="new_order",
            message=f"New order {order.order_number} from {customer.name} - Rs.{subtotal}",
        )
    )

    db.commit()
    db.refresh(order)

    message = _build_whatsapp_message(order)
    whatsapp_url = f"https://wa.me/{store.whatsapp_number}?text={quote(message)}"

    return OrderCreateResponse(order=OrderOut.model_validate(order), whatsapp_message=message, whatsapp_url=whatsapp_url)


@router.get("", response_model=list[OrderOut])
def list_orders(
    status_filter: OrderStatus | None = Query(None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Order]:
    stmt = _order_query().order_by(Order.order_date.desc())

    if current_user.role == UserRole.OWNER:
        store = get_default_store(db)
        stmt = stmt.where(Order.store_id == store.id)
    else:
        stmt = stmt.where(Order.customer_id == current_user.id)

    if status_filter is not None:
        stmt = stmt.where(Order.status == status_filter)

    return list(db.scalars(stmt))


@router.get("/{order_id}", response_model=OrderOut)
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Order:
    order = db.scalar(_order_query().where(Order.id == order_id))
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    if current_user.role != UserRole.OWNER and order.customer_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You do not have access to this order")

    return order


@router.patch("/{order_id}/status", response_model=OrderOut)
def update_order_status(
    order_id: int,
    payload: OrderStatusUpdateRequest,
    db: Session = Depends(get_db),
    owner: User = Depends(require_owner),
) -> Order:
    order = db.scalar(_order_query().where(Order.id == order_id))
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    allowed = ORDER_STATUS_TRANSITIONS.get(order.status, set())
    if payload.status not in allowed:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Cannot move order from '{order.status.value}' to '{payload.status.value}'",
        )

    order.status = payload.status
    db.add(OrderStatusHistory(order_id=order.id, status=payload.status, changed_by_user_id=owner.id))
    db.commit()
    db.refresh(order)
    return order
