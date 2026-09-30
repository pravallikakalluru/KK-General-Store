import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/order.dart';
import '../utils/formatters.dart';
import 'order_status_badge.dart';

/// Reusable order summary row used in order-history / owner order lists.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showPrice = true,
    this.showStatus = true,
  });

  final Order order;
  final VoidCallback onTap;

  /// Owner order lists still need the total for fulfillment/accounting;
  /// customers no longer see any pricing anywhere in the app (matches the
  /// receipt, which dropped per-item prices and totals earlier), so their
  /// order history hides it here too.
  final bool showPrice;

  /// Owner order lists still need the status badge to manage fulfillment;
  /// customers' own order history hides it here (kept simple - order
  /// number, date, item count).
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (showStatus) OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                Formatters.dateTime(order.orderDate),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (order.customerName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  order.customerName,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  if (showPrice)
                    Text(
                      Formatters.currency(order.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
