import '../models/user.dart';
import 'api_client.dart';

class AuthResult {
  final String token;
  final User user;

  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Response from POST /auth/register — no token: the customer registers
/// first, then logs in separately via phone + OTP.
class RegisterResult {
  final String message;
  final User user;

  const RegisterResult({required this.message, required this.user});

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    return RegisterResult(
      message: json['message'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Response from POST /auth/otp/request.
class OtpRequestResult {
  final String message;
  final int expiresInSeconds;
  /// Only present in dev mode (no real SMS provider configured yet) — the
  /// app shows this directly instead of the customer reading it off a text.
  final String? devOtp;

  const OtpRequestResult({
    required this.message,
    required this.expiresInSeconds,
    this.devOtp,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      message: json['message'] as String,
      expiresInSeconds: json['expires_in_seconds'] as int,
      devOtp: json['dev_otp'] as String?,
    );
  }
}

/// Wraps the /auth/* endpoints defined in API_CONTRACT.md.
class AuthService {
  final ApiClient _client = ApiClient();

  /// Owner (password) login. Customers use [requestOtp] + [verifyOtp].
  Future<AuthResult> ownerLogin({
    required String phone,
    required String password,
  }) async {
    final response = await _client.dio.post(
      '/auth/login',
      data: {
        'phone': phone,
        'password': password,
      },
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Customer registration — collects the profile only, no password.
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
    final response = await _client.dio.post(
      '/auth/register',
      data: {
        'name': name,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        'address_line1': addressLine1,
        'town': town,
        'district': district,
        'state': state,
        'pincode': pincode,
      },
    );
    return RegisterResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OtpRequestResult> requestOtp(String phone) async {
    final response = await _client.dio.post(
      '/auth/otp/request',
      data: {'phone': phone},
    );
    return OtpRequestResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResult> verifyOtp({required String phone, required String code}) async {
    final response = await _client.dio.post(
      '/auth/otp/verify',
      data: {'phone': phone, 'code': code},
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> me() async {
    final response = await _client.dio.get('/auth/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}
