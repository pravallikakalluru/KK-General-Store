import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/vegetable_background.dart';

/// Registration collects the customer's profile only — no password. On
/// success, per API_CONTRACT.md `POST /auth/register`, the backend returns
/// no token; this screen shows a success dialog then sends the customer
/// back to the login screen to sign in with phone + OTP.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _townController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLine1Controller.dispose();
    _townController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await context.read<AuthProvider>().register(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            addressLine1: _addressLine1Controller.text.trim(),
            town: _townController.text.trim(),
            district: _districtController.text.trim(),
            state: _stateController.text.trim(),
            pincode: _pincodeController.text.trim(),
          );
      if (!mounted) return;
      await _showSuccessDialog(result.message);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccessDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
        title: const Text('Registration Successful'),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: PrimaryButton(
              label: 'Log In Now',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VegetableBackground(
        child: Column(
          children: [
            AppBar(
              title: const Text('Create Account'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Personal details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Full name',
                            controller: _nameController,
                            prefixIcon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _requiredValidator(v, 'Full name'),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Mobile number',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_android_outlined,
                            textInputAction: TextInputAction.next,
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
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Email (optional)',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Address',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Address line 1',
                            controller: _addressLine1Controller,
                            prefixIcon: Icons.home_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _requiredValidator(v, 'Address line 1'),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Town',
                            controller: _townController,
                            prefixIcon: Icons.location_city_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _requiredValidator(v, 'Town'),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'District',
                            controller: _districtController,
                            prefixIcon: Icons.map_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _requiredValidator(v, 'District'),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'State',
                            controller: _stateController,
                            prefixIcon: Icons.public_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _requiredValidator(v, 'State'),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Pincode',
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.pin_drop_outlined,
                            textInputAction: TextInputAction.done,
                            hintText: '6-digit PIN code',
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if (v.isEmpty) return 'Pincode is required';
                              if (!RegExp(r'^[1-9]\d{5}$').hasMatch(v)) {
                                return 'Enter a valid 6-digit pincode';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: 'Register',
                            isLoading: _isSubmitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
