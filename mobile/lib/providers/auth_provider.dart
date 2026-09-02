import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, ApiClient? apiClient})
      : _authService = authService ?? AuthService(),
        _apiClient = apiClient ?? ApiClient();

  final AuthService _authService;
  final ApiClient _apiClient;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isOwner => _user?.isOwner ?? false;
  bool get isCustomer => _user?.isCustomer ?? false;

  /// Called once on app start: checks secure storage for a saved token and,
  /// if present, calls GET /auth/me to restore the session.
  Future<void> restoreSession() async {
    final token = await _apiClient.readToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final user = await _authService.me();
      _user = user;
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _apiClient.clearToken();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Owner (password) login. Customers use [requestOtp] + [verifyOtp].
  ///
  /// Deliberately does NOT set status to `authenticating` before the call
  /// completes: SplashScreen treats `authenticating` as "replace the whole
  /// screen with a full-screen spinner," which would unmount LoginScreen
  /// mid-submit and silently swallow any error it tries to show (its catch
  /// block checks `mounted`, which would already be false). The button's
  /// own local `isLoading` state is what should show progress here; status
  /// only needs to change once the outcome (success/failure) is known.
  Future<bool> ownerLogin({required String phone, required String password}) async {
    _errorMessage = null;
    try {
      final result = await _authService.ownerLogin(phone: phone, password: password);
      await _apiClient.saveToken(result.token);
      _user = result.user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  /// Registers the customer's profile. Does NOT log them in — no token is
  /// returned by the backend for registration; the caller shows the success
  /// message and sends the customer to the OTP login flow.
  Future<RegisterResult> register({
    required String name,
    required String phone,
    String? email,
    required String addressLine1,
    required String town,
    required String district,
    required String state,
    required String pincode,
  }) async {
    return _authService.register(
      name: name,
      phone: phone,
      email: email,
      addressLine1: addressLine1,
      town: town,
      district: district,
      state: state,
      pincode: pincode,
    );
  }

  /// Step 1 of customer login: request a fresh OTP for [phone]. Doesn't
  /// change auth status — the customer isn't logged in until [verifyOtp]
  /// succeeds.
  Future<OtpRequestResult> requestOtp(String phone) {
    return _authService.requestOtp(phone);
  }

  /// Step 2 of customer login: verify the OTP and, on success, complete
  /// authentication. See [ownerLogin]'s doc comment for why this must NOT
  /// set status to `authenticating` before the result is known.
  Future<bool> verifyOtp({required String phone, required String code}) async {
    _errorMessage = null;
    try {
      final result = await _authService.verifyOtp(phone: phone, code: code);
      await _apiClient.saveToken(result.token);
      _user = result.user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _apiClient.clearToken();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
