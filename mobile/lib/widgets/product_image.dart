import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The single product-image container used everywhere a product photo is
/// shown (grid card, detail screen, cart row, owner list, product form
/// preview) — always a square, white background, the product fully visible
/// with generous whitespace on every side, never cropped, never touching
/// the container edges.
///
/// Uses Flutter's own [Image.network] (backed by the framework's built-in
/// ImageCache) rather than the cached_network_image package: that package's
/// disk-cache layer has known reliability problems specifically on Flutter
/// Web (images rendering blank on a repeat load after the first one worked
/// fine), which is exactly the failure mode this replaced. Image.network
/// with gaplessPlayback avoids that whole class of bug — no custom cache
/// manager, no blank frame while a new image resolves.
///
/// The real fruit photos (backend/apply_fruit_photos.py) already bake
/// ~62% product fill + white margin directly into the file, so this
/// widget's [imageScale] only needs to be a light safety margin on top of
/// that — not a second, compounding shrink. It still matters for anything
/// that ISN'T pre-normalized (a generated icon placeholder, or any photo an
/// owner uploads later straight from their phone with no margin at all):
/// [imageScale] constrains the image's bounding box to a fixed fraction of
/// the container (via FractionallySizedBox) regardless of how tightly the
/// source happens to be framed, so nothing can ever end up touching the
/// container edges.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.size,
    this.fill = false,
    this.borderRadius,
    this.imageScale = 0.95,
    this.placeholderIconSize = 36,
  });

  /// Already-resolved absolute image URL (see ApiConfig.resolveImageUrl).
  final String imageUrl;

  /// Fixed width/height (e.g. a 56x56 list-row thumbnail). If null and
  /// [fill] is false, the image sizes itself to a 1:1 square filling its
  /// parent's width (grid cards, banners).
  final double? size;

  /// True when an ancestor (e.g. a Stack's Positioned.fill, used to overlay
  /// badges/controls on top of the image) already constrains this widget's
  /// size — skips the self-sizing AspectRatio/SizedBox wrapper.
  final bool fill;

  final BorderRadius? borderRadius;

  /// Fraction (0-1) of the container's width/height the image's bounding
  /// box is allowed to occupy — the rest is guaranteed whitespace on every
  /// side. 0.95 is a light safety margin on top of the ~62% fill already
  /// baked into the normalized product photos (landing the final result in
  /// the 55-70% target), while still guaranteeing *some* whitespace for
  /// any image that isn't pre-normalized.
  final double imageScale;

  final double placeholderIconSize;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius),
      clipBehavior: borderRadius != null ? Clip.antiAlias : Clip.none,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: imageScale,
          heightFactor: imageScale,
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  // Keeps showing the previous frame instead of a blank gap
                  // while a new image resolves (e.g. this widget getting
                  // rebuilt with the same URL as the grid scrolls) — the
                  // standard Flutter fix for images "disappearing" on
                  // rebuild, using the framework's own image cache rather
                  // than a third-party disk-cache layer.
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );

    if (fill) return box;
    if (size != null) {
      return SizedBox(width: size, height: size, child: box);
    }
    return AspectRatio(aspectRatio: 1, child: box);
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        Icons.shopping_basket_outlined,
        size: placeholderIconSize,
        color: AppColors.textSecondary,
      ),
    );
  }
}
