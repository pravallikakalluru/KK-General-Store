import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/loading_indicator.dart';
import 'orders_screen.dart';
import 'products_screen.dart';

/// Owner landing screen: quick stats + shortcuts. Built from the same
/// GET /orders and GET /products the Orders/Products screens use — no
/// dedicated stats endpoint is defined in API_CONTRACT.md.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        context.read<OrderProvider>().loadOrders(),
        context.read<ProductProvider>().loadProducts(),
      ]);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingIndicator()
            : Consumer2<OrderProvider, ProductProvider>(
                builder: (context, orderProvider, productProvider, _) {
                  final orders = orderProvider.orders;
                  final pendingCount =
                      orders.where((o) => o.status == OrderStatus.pending).length;
                  final preparingCount = orders
                      .where((o) => o.status == OrderStatus.preparing || o.status == OrderStatus.confirmed)
                      .length;
                  final completedCount =
                      orders.where((o) => o.status == OrderStatus.completed).length;
                  final productCount = productProvider.allProducts.length;
                  final outOfStockCount =
                      productProvider.allProducts.where((p) => !p.isAvailable).length;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Welcome back, ${user?.name ?? 'Owner'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Here's what's happening in your store today",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _StatCard(
                            label: 'Pending Orders',
                            value: '$pendingCount',
                            icon: Icons.pending_actions,
                            color: AppColors.statusPending,
                            onTap: () => _openOrders(context),
                          ),
                          _StatCard(
                            label: 'In Progress',
                            value: '$preparingCount',
                            icon: Icons.local_shipping_outlined,
                            color: AppColors.statusPreparing,
                            onTap: () => _openOrders(context),
                          ),
                          _StatCard(
                            label: 'Completed',
                            value: '$completedCount',
                            icon: Icons.check_circle_outline,
                            color: AppColors.statusCompleted,
                            onTap: () => _openOrders(context),
                          ),
                          _StatCard(
                            label: 'Products',
                            value: '$productCount',
                            icon: Icons.inventory_2_outlined,
                            color: AppColors.primary,
                            onTap: () => _openProducts(context),
                          ),
                        ],
                      ),
                      if (outOfStockCount > 0) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: AppColors.warning.withOpacity(0.08),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                            title: Text('$outOfStockCount product${outOfStockCount == 1 ? '' : 's'} out of stock'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openProducts(context),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }

  void _openOrders(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
    );
  }

  void _openProducts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductsScreen()),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
