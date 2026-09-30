import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // A gradient (not a flat fill) plus a real drop shadow gives the
        // header some depth instead of sitting as a plain color bar flush
        // with the page - the same "elevated surface" language as the
        // search bar and product cards below it.
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.25),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('KK General Store'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                // A floating elevated search bar (white surface + soft
                // shadow, no visible border) instead of the flat outlined
                // field the default input theme gives every other text
                // field in the app - this is the one screen asking for a
                // richer, more "hero" treatment.
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
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
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
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
        // "All" stays pinned at a fixed position while the rest of the
        // categories scroll independently beside it — the standard
        // grocery-app pattern (Blinkit/Swiggy Instamart-style), rather than
        // one long scrolling row where "All" itself scrolls out of view.
        return SizedBox(
          height: 40,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: CategoryChip(
                  label: 'All',
                  selected: productProvider.selectedCategoryId == null,
                  onTap: () => productProvider.setCategoryFilter(null),
                ),
              ),
              Container(
                height: 22,
                width: 1,
                margin: const EdgeInsets.only(right: 8),
                color: AppColors.divider,
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  children: categories
                      .map(
                        (category) => CategoryChip(
                          label: category.name,
                          selected: productProvider.selectedCategoryId == category.id,
                          onTap: () => productProvider.setCategoryFilter(category.id),
                        ),
                      )
                      .toList(),
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
          // MaxCrossAxisExtent (not a fixed crossAxisCount) so the number of
          // columns adapts to whatever width is actually available — a
          // hardcoded "always 3 columns" doesn't know the difference between
          // a normal mobile viewport and a zoomed-in one with much less
          // effective width, so at high browser zoom it was squeezing 3
          // columns into a narrow space and (since the aspect ratio is
          // fixed) stretching every card badly out of proportion instead of
          // just showing fewer, still-reasonably-sized columns. This also
          // means more columns show naturally on a wide desktop window.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            // Slightly shorter than before (0.6 -> 0.57): the ADD control
            // moved off the photo into its own row below the text, which
            // needs a little more vertical room than the old floating
            // overlay did.
            childAspectRatio: 0.57,
            // A bit more breathing room than before (each card now carries
            // its own drop shadow, which needs some clearance to read as a
            // separate lifted surface rather than crowding its neighbors).
            crossAxisSpacing: 14,
            mainAxisSpacing: 20,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              key: ValueKey(product.id),
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
