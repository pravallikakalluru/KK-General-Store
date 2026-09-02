import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/constants.dart';

/// Wraps a singleton [Dio] instance configured with the API base URL and
/// an interceptor that attaches the JWT (if present) to every outgoing
/// request's Authorization header, per API_CONTRACT.md
/// ("All authenticated requests send `Authorization: Bearer <jwt>`").
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  // flutter_secure_storage's web backend requires the Web Crypto API,
  // which browsers only expose in a secure context (HTTPS, or the literal
  // host "localhost") — it throws "Null check operator used on a null
  // value" when the app is served over plain HTTP from any other address
  // (e.g. a LAN IP), which is exactly how this app gets shared for testing.
  // shared_preferences (backed by localStorage) has no such restriction,
  // so it's used on web; native platforms keep the real Keychain/Keystore.
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Dio get dio => _dio;

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.secureStorageTokenKey, token);
    } else {
      await _secureStorage.write(key: AppConstants.secureStorageTokenKey, value: token);
    }
  }

  Future<String?> readToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.secureStorageTokenKey);
    }
    return _secureStorage.read(key: AppConstants.secureStorageTokenKey);
  }

  Future<void> clearToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.secureStorageTokenKey);
    } else {
      await _secureStorage.delete(key: AppConstants.secureStorageTokenKey);
    }
  }
}
