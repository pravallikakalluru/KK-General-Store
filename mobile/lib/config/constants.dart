/// App-wide constants that aren't strictly "config" (URLs/theme) but are
/// shared across multiple screens/services.
class AppConstants {
  AppConstants._();

  static const String appName = 'KK General Store';

  static const String secureStorageTokenKey = 'auth_token';

  /// How often the owner's orders screen polls for unread notification
  /// counts, per API_CONTRACT.md.
  static const Duration notificationPollInterval = Duration(seconds: 15);

  /// Placeholder used when a product has no image_url.
  static const String placeholderProductImage =
      'assets/images/placeholder_product.png';

  /// Forward-only status transitions, mirrored from API_CONTRACT.md.
  /// cancelled is reachable from any non-terminal state (handled separately).
  static const Map<String, String?> nextStatus = {
    'pending': 'confirmed',
    'confirmed': 'preparing',
    'preparing': 'ready',
    'ready': 'completed',
    'completed': null,
    'cancelled': null,
  };
}
