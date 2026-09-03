import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
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

    final hasDescription = product.description != null && product.description!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A fixed height (not the widget's default 1:1-of-width square)
            // — on a wide web/desktop viewport, CrossAxisAlignment.stretch
            // makes the image as wide as the screen, and a perfect square
            // banner would then be just as tall: the 500px source photo got
            // blown up to fill that (badly blurred) and pushed all the page
            // content far below the fold. A fixed height keeps the banner a
            // sane, consistent size on any screen width; BoxFit.contain
            // inside ProductImage still shows the full photo either way.
            SizedBox(
              height: 300,
              child: ProductImage(
                imageUrl: imageUrl,
                fill: true,
                placeholderIconSize: 64,
              ),
            ),
            // Content sits in a rounded-top sheet overlapping the image
            // banner slightly, the standard "bottom sheet over hero image"
            // layout used by Blinkit/Instamart/Zepto-style product pages —
            // it reads as one deliberate layout rather than a plain list of
            // text stacked under a photo.
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                              if (product.nameTe != null && product.nameTe!.isNotEmpty) ...[
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.error.withOpacity(0.4)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Formatters.currency(product.price),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ ${product.unit}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildTrustBadges(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: product.isAvailable ? _buildAddToCartBar(context) : null,
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
                  context.read<CartProvider>().addProduct(widget.product, quantity: _quantity);
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
