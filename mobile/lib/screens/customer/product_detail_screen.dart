import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageUrl = ApiConfig.resolveImageUrl(product.imageUrl);
    final cartProvider = context.watch<CartProvider>();
    final alreadyInCart = cartProvider.quantityOf(product.id);

    final hasDescription =
        product.description != null && product.description!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(product.name)),
      // LayoutBuilder (not a plain scrolling Column) so the photo gets a
      // fixed 70% of the actual available screen height — the product
      // should read as the dominant thing on the page, the way a
      // photo-forward grocery app shows it, not a small banner above a
      // long scroll of text. The info panel below gets the remaining 30%
      // and scrolls internally if its own content (description, badges)
      // runs past that.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxHeight * 0.7;
          return Column(
            children: [
              // Width is separately capped at 500 (the source photos' own
              // canvas size) and centered — on a wide desktop viewport, a
              // full-width square-ish photo constrained only by height
              // would otherwise shrink down to fit and leave huge empty
              // backdrop on either side instead of a properly-sized,
              // centered photo.
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: ProductImage(
                      imageUrl: imageUrl,
                      fill: true,
                      placeholderIconSize: 64,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Transform.translate(
                    // Content sits in a rounded-top sheet overlapping the
                    // image slightly, the standard "bottom sheet over hero
                    // image" layout used by Blinkit/Instamart/Zepto-style
                    // product pages — it reads as one deliberate layout
                    // rather than a plain list of text stacked under a
                    // photo.
                    offset: const Offset(0, -20),
                    child: Container(
                      constraints: BoxConstraints(
                          minHeight: constraints.maxHeight * 0.3 + 20),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (product.nameTe != null &&
                                        product.nameTe!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        product.nameTe!,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!product.isAvailable)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            AppColors.error.withOpacity(0.4)),
                                  ),
                                  child: const Text(
                                    'Out of stock',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            AppColors.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    product.unit,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sold per ${product.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (alreadyInCart > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              '$alreadyInCart already in your cart',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                          if (hasDescription) ...[
                            const Text(
                              'About this product',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, height: 1.5),
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildTrustBadges(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar:
          product.isAvailable ? _buildAddToCartBar(context) : null,
    );
  }

  Widget _buildTrustBadges() {
    final badges = [
      (Icons.eco_outlined, 'Farm Fresh'),
      (Icons.verified_outlined, 'Quality Checked'),
      (Icons.bolt_outlined, 'Quick Delivery'),
    ];
    return Row(
      children: badges
          .map(
            (badge) => Expanded(
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badge.$1, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAddToCartBar(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            QuantityStepper(
              quantity: _quantity,
              onIncrement: () => setState(() => _quantity++),
              onDecrement: () => setState(() {
                if (_quantity > 1) _quantity--;
              }),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: PrimaryButton(
                label: 'Add to Cart',
                icon: Icons.shopping_cart_outlined,
                onPressed: () {
                  context
                      .read<CartProvider>()
                      .addProduct(widget.product, quantity: _quantity);
                  ErrorHandler.showMessage(
                    context,
                    '${widget.product.name} added to cart',
                  );
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
