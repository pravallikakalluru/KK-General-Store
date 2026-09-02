import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/receipt_pdf_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/primary_button.dart';
import 'customer_shell.dart';

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _isSharingReceipt = false;

  Future<void> _shareReceipt() async {
    setState(() => _isSharingReceipt = true);
    try {
      await ReceiptPdfService.shareReceipt(widget.order);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSharingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Placed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OrderStatusBadge(status: order.status),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        Formatters.currency(order.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We sent your order to the store via WhatsApp. You can track its status from Order History.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Download Receipt',
                icon: Icons.download_outlined,
                outlined: true,
                isLoading: _isSharingReceipt,
                onPressed: _shareReceipt,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Share via WhatsApp',
                icon: Icons.chat_bubble_outline,
                outlined: true,
                isLoading: _isSharingReceipt,
                onPressed: _shareReceipt,
              ),
              const SizedBox(height: 6),
              const Text(
                'Opens your share menu — pick WhatsApp to send the receipt to a contact',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Continue Shopping',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const CustomerShell()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
