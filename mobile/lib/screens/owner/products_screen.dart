import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/product_image.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        context.read<ProductProvider>().loadProducts(),
        context.read<CategoryProvider>().loadCategories(),
      ]);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<ProductProvider>().deleteProduct(product.id);
      if (mounted) ErrorHandler.showMessage(context, 'Product removed');
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  Future<void> _toggleAvailability(Product product, bool value) async {
    try {
      await context.read<ProductProvider>().toggleAvailability(product.id, value);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Consumer2<ProductProvider, CategoryProvider>(
          builder: (context, productProvider, categoryProvider, _) {
            if (productProvider.isLoading && productProvider.allProducts.isEmpty) {
              return const LoadingIndicator();
            }

            final products = productProvider.allProducts;

            if (products.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    subtitle: 'Tap + to add your first product',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = products[index];
                final category = categoryProvider.byId(product.categoryId);
                final imageUrl = ApiConfig.resolveImageUrl(product.imageUrl);

                return Card(
                  key: ValueKey(product.id),
                  child: ListTile(
                    onTap: () => _openForm(product: product),
                    leading: ProductImage(
                      imageUrl: imageUrl,
                      size: 48,
                      borderRadius: BorderRadius.circular(8),
                      placeholderIconSize: 20,
                    ),
                    title: Text(
                      product.nameTe != null && product.nameTe!.isNotEmpty
                          ? '${product.name}  ·  ${product.nameTe}'
                          : product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${category?.name ?? 'Uncategorized'} · ${Formatters.currency(product.price)} / ${product.unit}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: product.isAvailable,
                          onChanged: (value) => _toggleAvailability(product, value),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          onPressed: () => _confirmDelete(product),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
