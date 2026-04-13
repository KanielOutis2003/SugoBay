import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    // Remove leading 0 if user types 09xx format
    final cleaned = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+63$cleaned';
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.auth.signInWithOtp(phone: _fullPhone);
      if (!mounted) return;
      showSugoBaySnackBar(context, 'OTP sent to $_fullPhone');
      context.push('/otp', extra: _fullPhone);
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(
        context,
        'Failed to send OTP: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 28,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.tagline,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 48),

                // Phone input
                Text(
                  'Enter your phone number',
                  style: AppTextStyles.subheading,
                ),
                const SizedBox(height: 8),
                Text(
                  'We will send you a one-time verification code',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 24),

                SugoBayTextField(
                  label: 'Phone Number',
                  hint: '9XX XXX XXXX',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefix: Container(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    alignment: Alignment.center,
                    width: 60,
                    child: Text(
                      '+63',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    final cleaned =
                        value.trim().startsWith('0')
                            ? value.trim().substring(1)
                            : value.trim();
                    if (cleaned.length != 10 ||
                        !RegExp(r'^\d{10}$').hasMatch(cleaned)) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Send OTP button
                SugoBayButton(
                  text: 'Send OTP',
                  onPressed: _sendOtp,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 32),
                Text(
                  'By continuing, you agree to our Terms of Service',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
