import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/enums.dart';

/// Colored pill showing an order's status. Used everywhere an order status
/// is shown, including in lists, per the architecture requirement.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status, this.compact = false});

  final OrderStatus status;
  final bool compact;

  Color get _color {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.statusPending;
      case OrderStatus.confirmed:
        return AppColors.statusConfirmed;
      case OrderStatus.preparing:
        return AppColors.statusPreparing;
      case OrderStatus.ready:
        return AppColors.statusReady;
      case OrderStatus.completed:
        return AppColors.statusCompleted;
      case OrderStatus.cancelled:
        return AppColors.statusCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 12.5,
        ),
      ),
    );
  }
}
