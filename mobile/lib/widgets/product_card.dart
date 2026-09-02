import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/product.dart';
import '../utils/formatters.dart';

/// Product grid tile, Blinkit-style: a square product image with a floating
/// quantity control overlapping its bottom-right corner, then unit, name
/// (English + Telugu), and price below. Out-of-stock products are shown
/// greyed out and not addable. Designed for a 3-column grid.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.cartQuantity = 0,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  final Product product;
  final VoidCallback onTap;
  final int cartQuantity;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final isAvailable = product.isAvailable;
    final imageUrl = ApiConfig.resolveImageUrl(product.imageUrl);

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.divider,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                    ),
                  ),
                  if (!isAvailable)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Out of stock',
                          style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (isAvailable)
                    Positioned(
                      right: -4,
                      bottom: -14,
                      child: _buildQuantityControl(context),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '/ ${product.unit}',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.2),
            ),
            if (product.nameTe != null && product.nameTe!.isNotEmpty)
              Text(
                product.nameTe!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 3),
            Text(
              Formatters.currency(product.price),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl(BuildContext context) {
    if (cartQuantity <= 0) {
      return InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: const Icon(Icons.add, color: AppColors.primary, size: 18),
        ),
      );
    }

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(Icons.remove, onDecrement),
          SizedBox(
            width: 20,
            child: Text(
              '$cartQuantity',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          _stepperButton(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Icon(icon, color: Colors.white, size: 13),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.divider,
      child: const Center(
        child: Icon(Icons.shopping_basket_outlined, size: 28, color: AppColors.textSecondary),
      ),
    );
  }
}
