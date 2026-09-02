import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/enums.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../services/receipt_pdf_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/primary_button.dart';

/// Owner's order detail screen: full item breakdown, status transition
/// controls (forward-only per API_CONTRACT.md, cancel from any
/// non-terminal state), and a "print receipt" action that sends the
/// shared receipt PDF straight to Android's print dialog.
class OwnerOrderDetailScreen extends StatefulWidget {
  const OwnerOrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OwnerOrderDetailScreen> createState() => _OwnerOrderDetailScreenState();
}

class _OwnerOrderDetailScreenState extends State<OwnerOrderDetailScreen> {
  Order? _order;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isPrinting = false;
  bool _isSharingReceipt = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final order = await context.read<OrderProvider>().getOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(OrderStatus status) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final updated = await context
          .read<OrderProvider>()
          .updateOrderStatus(id: widget.orderId, status: status);
      if (mounted) {
        setState(() => _order = updated);
        ErrorHandler.showMessage(context, 'Order marked as ${status.label}');
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('This will mark the order as cancelled. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus(OrderStatus.cancelled);
    }
  }

  Future<void> _printReceipt() async {
    final order = _order;
    if (order == null) return;
    setState(() => _isPrinting = true);
    try {
      await ReceiptPdfService.printReceipt(order);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _shareReceipt() async {
    final order = _order;
    if (order == null) return;
    setState(() => _isSharingReceipt = true);
    try {
      await ReceiptPdfService.shareReceipt(order);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSharingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(order?.orderNumber ?? 'Order Details'),
        actions: [
          if (order != null)
            IconButton(
              icon: _isPrinting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_outlined),
              onPressed: _isPrinting ? null : _printReceipt,
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : order == null
              ? const Center(child: Text('Order not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order.orderNumber,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            OrderStatusBadge(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Formatters.dateTime(order.orderDate),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(order.customerName),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(order.customerPhone),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                ...order.items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Text(
                                                '${Formatters.currency(item.productPrice)} x ${item.quantity}',
                                                style: const TextStyle(
                                                    fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          Formatters.currency(item.lineTotal),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Subtotal'),
                                    Text(Formatters.currency(order.subtotal)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      Formatters.currency(order.totalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('Order Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text(order.notes!, style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 28),
                        _buildStatusActions(order),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Print Receipt',
                          icon: Icons.print_outlined,
                          outlined: true,
                          isLoading: _isPrinting,
                          onPressed: _printReceipt,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Share via WhatsApp',
                          icon: Icons.chat_bubble_outline,
                          outlined: true,
                          isLoading: _isSharingReceipt,
                          onPressed: _shareReceipt,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusActions(Order order) {
    if (order.status.isTerminal) {
      return const SizedBox.shrink();
    }

    final nextStatusName = AppConstants.nextStatus[order.status.toJson()];
    final nextStatus = nextStatusName != null ? OrderStatus.fromJson(nextStatusName) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nextStatus != null)
          PrimaryButton(
            label: 'Mark as ${nextStatus.label}',
            icon: Icons.arrow_forward,
            isLoading: _isUpdatingStatus,
            onPressed: () => _updateStatus(nextStatus),
          ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Cancel Order',
          icon: Icons.cancel_outlined,
          outlined: true,
          isLoading: _isUpdatingStatus,
          onPressed: _confirmCancel,
        ),
      ],
    );
  }
}
