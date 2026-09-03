import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place to configure the backend base URL.
///
/// Update [_devHost] to point at your running FastAPI backend before
/// building/running the app. During local development on a physical
/// Android device or emulator, `localhost` on your dev machine is NOT
/// reachable directly:
///   - Chrome/web or Windows desktop: `localhost` works (handled automatically below)
///   - Android emulator: use `http://10.0.2.2:8000/api/v1` (the default below)
///   - Physical device on same Wi-Fi: use `http://<your-lan-ip>:8000/api/v1`
///   - iOS simulator: `http://localhost:8000/api/v1` works
class ApiConfig {
  ApiConfig._();

  /// Host:port for everything except web (Android emulator alias by default).
  static const String _devHost = '10.0.2.2:8000';

  /// Backend port, reused with whatever host the web app itself was loaded
  /// from (see [_webHost]).
  static const String _backendPort = '8000';

  /// On web, derives the backend host from the page's OWN address
  /// (Uri.base.host — works in a browser without any web-only import)
  /// instead of a hardcoded IP: whether this was opened as
  /// http://localhost:5000 or http://<whatever-the-LAN-IP-currently-is>:5000,
  /// API calls automatically go to that same host on the backend's port.
  /// A hardcoded LAN IP breaks the moment DHCP hands this machine a
  /// different address (which is exactly what happened once already) —
  /// this has no such expiry date.
  static String get _webHost => '${Uri.base.host}:$_backendPort';

  /// Base URL for all API calls, matching API_CONTRACT.md:
  /// Base URL (dev): http://<host>:8000/api/v1
  static String get baseUrl =>
      kIsWeb ? 'http://$_webHost/api/v1' : 'http://$_devHost/api/v1';

  /// Host root (no /api/v1 suffix) — used to resolve relative image URLs
  /// such as `/static/products/<filename>` returned by the backend.
  static String get hostRoot => kIsWeb ? 'http://$_webHost' : 'http://$_devHost';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Resolves a possibly-relative image URL (e.g. "/static/products/x.jpg")
  /// returned by the backend into an absolute URL usable by
  /// Image.network (see widgets/product_image.dart). Already-absolute URLs
  /// are returned unchanged.
  static String resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('/')) {
      return '$hostRoot$imageUrl';
    }
    return '$hostRoot/$imageUrl';
  }
}
