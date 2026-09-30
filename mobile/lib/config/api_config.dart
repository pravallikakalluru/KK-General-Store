import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

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

  /// REQUIRED before a Play Store release build: the real, publicly
  /// reachable backend this app will talk to once installed on someone
  /// else's phone, on someone else's network — 10.0.2.2 only resolves
  /// inside the Android emulator, so it's useless here. Needs a real
  /// domain with a real (non-self-signed) TLS certificate; Android also
  /// blocks plain http:// by default (see android/app/src/main/res/xml/
  /// network_security_config.xml), so this must be https://.
  static const String _prodBaseUrl = 'https://TODO-set-real-backend-domain.example.com/api/v1';
  static const String _prodHostRoot = 'https://TODO-set-real-backend-domain.example.com';

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
  ///
  /// This assumes the frontend and backend share one hostname, differing
  /// only by port — true for the plain LAN setup, but NOT true once the
  /// frontend and backend are each put behind their own tunnel/proxy (e.g.
  /// a Cloudflare Tunnel per service), which get two entirely different
  /// hostnames with no meaningful "backend port" on either. [_backendUrlOverride]
  /// covers that case: if set, it's used as-is instead of this derivation.
  static String get _webHost => '${Uri.base.host}:$_backendPort';

  /// Matches the page's OWN scheme rather than hardcoding http:// — when
  /// the app is served over HTTPS (needed for real native file-sharing to
  /// WhatsApp: browsers only allow navigator.share() with files in a
  /// "secure context", which plain HTTP never satisfies), API calls must
  /// also go out over HTTPS or the browser blocks them as mixed content.
  static String get _webScheme => Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;

  /// Optional build-time override for the backend's full origin (scheme +
  /// host, no trailing slash, no /api/v1) — e.g.
  /// `flutter build web --dart-define=BACKEND_URL=https://my-backend.trycloudflare.com`.
  /// Takes priority over every other rule below, on every platform. Empty
  /// (the default) means "no override, use the normal same-host / dev-host
  /// / prod-placeholder rules instead".
  static const String _backendUrlOverride = String.fromEnvironment('BACKEND_URL');

  /// Base URL for all API calls, matching API_CONTRACT.md:
  /// Base URL (dev): http://<host>:8000/api/v1
  ///
  /// Non-web release builds use [_prodBaseUrl] (must be set to the real
  /// backend before shipping); non-web debug builds keep using the local
  /// dev host (emulator alias / LAN IP) so `flutter run` still works
  /// unchanged during development.
  static String get baseUrl {
    if (_backendUrlOverride.isNotEmpty) return '$_backendUrlOverride/api/v1';
    if (kIsWeb) return '$_webScheme://$_webHost/api/v1';
    return kDebugMode ? 'http://$_devHost/api/v1' : _prodBaseUrl;
  }

  /// Host root (no /api/v1 suffix) — used to resolve relative image URLs
  /// such as `/static/products/<filename>` returned by the backend.
  static String get hostRoot {
    if (_backendUrlOverride.isNotEmpty) return _backendUrlOverride;
    if (kIsWeb) return '$_webScheme://$_webHost';
    return kDebugMode ? 'http://$_devHost' : _prodHostRoot;
  }

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
