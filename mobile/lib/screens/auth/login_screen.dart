import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/otp_box_input.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/vegetable_background.dart';
import 'register_screen.dart';

enum _LoginMode { customerPhone, customerOtp, owner }

/// Customer login is phone + OTP (default). A small link switches to the
/// owner's phone + password login. See API_CONTRACT.md "Login" section for
/// the OTP rules this screen mirrors (4-digit code, 2-minute expiry, 3 wrong
/// attempts -> 10-minute lockout).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginMode _mode = _LoginMode.customerPhone;

  final _phoneFormKey = GlobalKey<FormState>();
  final _ownerFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _otpInputKey = GlobalKey<OtpBoxInputState>();

  bool _obscurePassword = true;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isOwnerSubmitting = false;

  String? _otpPhone;
  String? _devOtp;
  String? _otpError;
  String? _lockoutMessage;
  int _secondsRemaining = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _ownerPhoneController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _secondsRemaining = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String get _timerText {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    setState(() {
      _isSendingOtp = true;
      _lockoutMessage = null;
    });
    try {
      final result = await context.read<AuthProvider>().requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _mode = _LoginMode.customerOtp;
        _otpPhone = phone;
        _devOtp = result.devOtp;
        _otpError = null;
      });
      _startTimer(result.expiresInSeconds);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_otpPhone == null) return;
    setState(() {
      _isSendingOtp = true;
      _otpError = null;
      _lockoutMessage = null;
    });
    try {
      final result = await context.read<AuthProvider>().requestOtp(_otpPhone!);
      if (!mounted) return;
      _otpInputKey.currentState?.clear();
      setState(() => _devOtp = result.devOtp);
      _startTimer(result.expiresInSeconds);
      ErrorHandler.showMessage(context, 'A new OTP has been sent.');
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp(String code) async {
    if (_otpPhone == null || _isVerifyingOtp) return;
    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
    });
    try {
      await context.read<AuthProvider>().verifyOtp(phone: _otpPhone!, code: code);
      // Root SplashScreen handles navigation to the customer shell once
      // AuthProvider.status flips to authenticated.
    } catch (e) {
      if (!mounted) return;
      final message = ErrorHandler.messageFor(e);
      setState(() {
        if (message.toLowerCase().contains('too many')) {
          _lockoutMessage = message;
          _otpError = null;
        } else {
          _otpError = message;
        }
      });
      _otpInputKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _mode = _LoginMode.customerPhone;
      _otpPhone = null;
      _devOtp = null;
      _otpError = null;
      _lockoutMessage = null;
      _secondsRemaining = 0;
    });
  }

  Future<void> _ownerLogin() async {
    if (!_ownerFormKey.currentState!.validate()) return;
    setState(() => _isOwnerSubmitting = true);
    try {
      await context.read<AuthProvider>().ownerLogin(
            phone: _ownerPhoneController.text.trim(),
            password: _ownerPasswordController.text,
          );
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isOwnerSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VegetableBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                const Icon(Icons.shopping_basket, color: Colors.white, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'KK General Store',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fresh groceries, delivered to your door',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildModeContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent() {
    switch (_mode) {
      case _LoginMode.customerPhone:
        return _buildPhoneStep();
      case _LoginMode.customerOtp:
        return _buildOtpStep();
      case _LoginMode.owner:
        return _buildOwnerStep();
    }
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Log in with your mobile number',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Mobile number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_android_outlined,
            textInputAction: TextInputAction.done,
            hintText: '10-digit mobile number',
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Mobile number is required';
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                return 'Enter a valid 10-digit Indian mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Send OTP',
            isLoading: _isSendingOtp,
            onPressed: _sendOtp,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text('Register'),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _mode = _LoginMode.owner),
              child: const Text('Login as Owner instead'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final expired = _secondsRemaining == 0;
    final locked = _lockoutMessage != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _changeNumber,
              tooltip: 'Change number',
            ),
            Expanded(
              child: Text(
                'Enter the OTP sent to +91 $_otpPhone',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_devOtp != null && !locked)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dev mode — no SMS provider configured. Your OTP is $_devOtp',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        if (locked)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 20, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_lockoutMessage!, style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        OtpBoxInput(
          key: _otpInputKey,
          length: 4,
          enabled: !locked && !_isVerifyingOtp,
          errorText: _otpError,
          onChanged: (_) {},
          onCompleted: _verifyOtp,
        ),
        const SizedBox(height: 18),
        if (_isVerifyingOtp)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: expired
                ? TextButton.icon(
                    onPressed: locked || _isSendingOtp ? null : _resendOtp,
                    icon: const Icon(Icons.refresh),
                    label: Text(_isSendingOtp ? 'Sending...' : 'Resend OTP'),
                  )
                : Text(
                    'OTP expires in $_timerText',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
          ),
      ],
    );
  }

  Widget _buildOwnerStep() {
    return Form(
      key: _ownerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _mode = _LoginMode.customerPhone),
              ),
              const Text(
                'Owner login',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Phone number',
            controller: _ownerPhoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Phone number is required' : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Password',
            controller: _ownerPasswordController,
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Log In',
            isLoading: _isOwnerSubmitting,
            onPressed: _ownerLogin,
          ),
        ],
      ),
    );
  }
}
