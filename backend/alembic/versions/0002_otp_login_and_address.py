"""OTP login + customer address fields

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-02

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("users", "password_hash", existing_type=sa.String(255), nullable=True)

    op.add_column("users", sa.Column("address_line1", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("town", sa.String(120), nullable=True))
    op.add_column("users", sa.Column("district", sa.String(120), nullable=True))
    op.add_column("users", sa.Column("state", sa.String(120), nullable=True))
    op.add_column("users", sa.Column("pincode", sa.String(10), nullable=True))
    op.add_column(
        "users", sa.Column("otp_failed_attempts", sa.Integer, nullable=False, server_default="0")
    )
    op.add_column("users", sa.Column("otp_locked_until", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "otp_codes",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id"), nullable=False),
        sa.Column("phone", sa.String(20), nullable=False),
        sa.Column("code", sa.String(4), nullable=False),
        sa.Column("purpose", sa.String(20), nullable=False, server_default="login"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_otp_codes_phone", "otp_codes", ["phone"])


def downgrade() -> None:
    op.drop_index("ix_otp_codes_phone", table_name="otp_codes")
    op.drop_table("otp_codes")

    op.drop_column("users", "otp_locked_until")
    op.drop_column("users", "otp_failed_attempts")
    op.drop_column("users", "pincode")
    op.drop_column("users", "state")
    op.drop_column("users", "district")
    op.drop_column("users", "town")
    op.drop_column("users", "address_line1")

    op.alter_column("users", "password_hash", existing_type=sa.String(255), nullable=False)
