import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/enums.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/order_summary_card.dart';
import 'order_detail_screen.dart';

/// Owner's full order list with status filter. Polls
/// GET /notifications/unread-count every ~15s while this screen is active,
/// per API_CONTRACT.md, to drive a badge.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      context.read<NotificationProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<NotificationProvider>().stopPolling();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await context.read<OrderProvider>().loadOrders(status: _filter);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  Future<void> _selectFilter(OrderStatus? status) async {
    setState(() => _filter = status);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifications, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () async {
                        try {
                          await notifications.markAllRead();
                        } catch (e) {
                          if (mounted) ErrorHandler.showError(context, e);
                        }
                      },
                    ),
                    if (notifications.unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            notifications.unreadCount > 99 ? '99+' : '${notifications.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(child: _buildOrderList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final options = <OrderStatus?>[null, ...OrderStatus.values];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final status = options[index];
          final selected = _filter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status?.label ?? 'All'),
              selected: selected,
              onSelected: (_) => _selectFilter(status),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList() {
    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.orders.isEmpty) {
          return const LoadingIndicator();
        }

        if (provider.orders.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 100),
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders found',
                subtitle: 'Orders placed by customers will show up here',
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.orders.length,
          itemBuilder: (context, index) {
            final order = provider.orders[index];
            return OrderSummaryCard(
              order: order,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OwnerOrderDetailScreen(orderId: order.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
