import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/product.dart';
import 'product_image.dart';

/// Product grid tile: a square product photo, name (English + Telugu)
/// below, then a unit row with a proper ADD button (not floating on top of
/// the photo). Out-of-stock products are shown greyed out and not
/// addable. Designed for a 3-column grid. No price is shown — this app
/// keeps pricing conversations on WhatsApp rather than in-app.
///
/// All product photos sit on plain white — an earlier attempt at a warm
/// styled backdrop (procedurally generated, no real image-generation model
/// available in this environment) didn't hold up next to genuine
/// photography and was reverted.
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            // The whole card is now one elevated white surface (image + text
            // together) instead of just a bordered box around the image with
            // text floating directly on the page background - the soft
            // shadow is what gives the grid the "lifted card" depth typical
            // of Blinkit/Zepto/Instamart rather than a flat list of images.
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expanded (not a fixed square AspectRatio) so this image area
                // always exactly fills whatever vertical space is left over in
                // the card after the text block below, whatever that turns out
                // to be for the current column width. A fixed AspectRatio tied
                // to the card's width, combined with a single fixed
                // childAspectRatio on the surrounding GridView, only balances at
                // one specific column width — at any narrower width (which the
                // responsive grid produces often) the text needed more room than
                // was budgeted, the Column overflowed, and the image got clipped
                // at its bottom edge. Expanded makes overflow structurally
                // impossible regardless of column width or text length.
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ProductImage(
                            imageUrl: imageUrl,
                            fill: true,
                          ),
                        ),
                      ),
                      if (!isAvailable)
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'Out of stock',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Fixed-height reservation (not just maxLines) for the name -
                // a name that only needs 1 line would otherwise leave less
                // text below the image than a 2-line name in the same grid
                // row. Since the image area above is Expanded (fills whatever
                // space is left in the card), that variable leftover text
                // height meant the image box's actual height - and so its
                // bottom edge - shifted card to card instead of lining up.
                // Reserving the same space regardless of actual content keeps
                // every card's image box exactly the same size.
                SizedBox(
                  height: 32, // 2 lines at fontSize 13 * height 1.2
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2),
                    ),
                  ),
                ),
                SizedBox(
                  height: 14,
                  child: (product.nameTe != null && product.nameTe!.isNotEmpty)
                      ? Text(
                          product.nameTe!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.textSecondary),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                // Unit on the left, the ADD control on the right - its own
                // row below the text rather than floating over the photo, so
                // the image reads as a clean, unobstructed product shot.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.unit,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    if (isAvailable) _buildQuantityControl(context),
                  ],
                ),
              ],
            ),
          ),
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
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary),
          ),
          child: const Text(
            'ADD',
            style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.3),
          ),
        ),
      );
    }

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 1)),
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
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
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
}
