"""Add Telugu-name snapshot to order_items

Revision ID: 0005
Revises: 0004
Create Date: 2026-09-17

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "order_items", sa.Column("product_name_te", sa.String(255), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("order_items", "product_name_te")
