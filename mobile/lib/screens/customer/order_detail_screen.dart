import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../services/receipt_pdf_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../utils/receipt_share_helper.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/primary_button.dart';

/// Customer's view of a single order's detail + current status.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _whatsappService = WhatsappService();
  Order? _order;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isSharingToWhatsapp = false;

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

  Future<void> _downloadReceipt() async {
    final order = _order;
    if (order == null) return;
    setState(() => _isDownloading = true);
    try {
      await ReceiptPdfService.shareReceipt(order);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareReceiptToWhatsapp() async {
    final order = _order;
    if (order == null) return;
    setState(() => _isSharingToWhatsapp = true);
    try {
      // Try real native file sharing first (navigator.share on web) - when
      // it's supported, WhatsApp shows up in the OS share sheet with the
      // PDF itself, not just text. Only when this browser/platform can't
      // do that at all do we fall back to downloading the file and
      // walking the customer through attaching it by hand.
      final shared = await ReceiptPdfService.shareReceiptViaWhatsapp(order);
      if (!mounted) return;
      if (!shared) {
        await ReceiptPdfService.shareReceipt(order);
        if (!mounted) return;
        setState(() => _isSharingToWhatsapp = false);
        await shareReceiptToWhatsappContact(
          context: context,
          orderNumber: order.orderNumber,
          whatsappService: _whatsappService,
        );
        return;
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSharingToWhatsapp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(order?.orderNumber ?? 'Order Details')),
      body: _isLoading
          ? const LoadingIndicator()
          : order == null
              ? const Center(child: Text('Order not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
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
                                          child: Text(item.productName,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ),
                                        Text(
                                          '${item.unit} x ${item.quantity}',
                                          style: const TextStyle(
                                              fontSize: 12.5, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total items',
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      '${order.items.fold<int>(0, (sum, i) => sum + i.quantity)}',
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
                        if (order.statusHistory.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('Status History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          ...order.statusHistory.map(
                            (h) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  OrderStatusBadge(status: h.status, compact: true),
                                  const SizedBox(width: 10),
                                  Text(
                                    Formatters.dateTime(h.changedAt),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: 'Download Receipt',
                          icon: Icons.download_outlined,
                          outlined: true,
                          isLoading: _isDownloading,
                          onPressed: _downloadReceipt,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Share via WhatsApp',
                          icon: Icons.chat_bubble_outline,
                          outlined: true,
                          isLoading: _isSharingToWhatsapp,
                          onPressed: _shareReceiptToWhatsapp,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Opens your share menu — pick WhatsApp to send the receipt to a contact',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }
}
