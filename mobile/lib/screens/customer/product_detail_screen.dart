import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../widgets/primary_button.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
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
                        ),
                    ],
                  ),
                  if (product.nameTe != null && product.nameTe!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.nameTe!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Sold per ${product.unit}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    Formatters.currency(product.price),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (product.description != null && product.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description!,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                  if (alreadyInCart > 0) ...[
                    const SizedBox(height: 20),
                    Text(
                      '$alreadyInCart already in your cart',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: product.isAvailable ? _buildAddToCartBar(context) : null,
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.divider,
      child: const Center(
        child: Icon(Icons.shopping_basket_outlined, size: 64, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildAddToCartBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
