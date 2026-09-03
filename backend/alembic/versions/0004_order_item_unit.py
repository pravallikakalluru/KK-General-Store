"""Add unit snapshot to order_items

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-03

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "order_items", sa.Column("unit", sa.String(20), nullable=False, server_default="pc")
    )


def downgrade() -> None:
    op.drop_column("order_items", "unit")
