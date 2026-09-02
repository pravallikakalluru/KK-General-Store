import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final categoryProvider = context.read<CategoryProvider>();
    final productProvider = context.read<ProductProvider>();
    try {
      await Future.wait([
        categoryProvider.loadCategories(),
        productProvider.loadProducts(),
      ]);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KK General Store'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    context.read<ProductProvider>().setSearchQuery(value),
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<ProductProvider>().setSearchQuery('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
            _buildCategoryFilter(),
            const SizedBox(height: 4),
            Expanded(child: _buildProductGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Consumer2<CategoryProvider, ProductProvider>(
      builder: (context, categoryProvider, productProvider, _) {
        final categories = categoryProvider.categories;
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              CategoryChip(
                label: 'All',
                selected: productProvider.selectedCategoryId == null,
                onTap: () => productProvider.setCategoryFilter(null),
              ),
              ...categories.map(
                (category) => CategoryChip(
                  label: category.name,
                  selected: productProvider.selectedCategoryId == category.id,
                  onTap: () => productProvider.setCategoryFilter(category.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductGrid() {
    return Consumer2<ProductProvider, CartProvider>(
      builder: (context, productProvider, cartProvider, _) {
        if (productProvider.isLoading && productProvider.allProducts.isEmpty) {
          return const LoadingIndicator();
        }

        final products = productProvider.filteredProducts;

        if (products.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'No products found',
            subtitle: 'Try a different search or category',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 18,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              cartQuantity: cartProvider.quantityOf(product.id),
              onTap: () => _openDetail(product),
              onAdd: product.isAvailable
                  ? () {
                      cartProvider.addProduct(product);
                      ErrorHandler.showMessage(context, '${product.name} added to cart');
                    }
                  : null,
              onIncrement: () => cartProvider.incrementQuantity(product.id),
              onDecrement: () => cartProvider.decrementQuantity(product.id),
            );
          },
        );
      },
    );
  }

  void _openDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }
}
