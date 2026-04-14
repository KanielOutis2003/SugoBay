import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEmailLogin = true; // Email is primary

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    // Remove leading 0 if user types 09xx format
    final cleaned = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+63$cleaned';
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEmailLogin) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        await SupabaseService.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        final role = await SupabaseService.getUserRole();
        if (!mounted) return;
        _routeByRole(role);
      } else {
        await SupabaseService.auth.signInWithOtp(phone: _fullPhone);
        if (!mounted) return;
        showSugoBaySnackBar(context, 'OTP sent to $_fullPhone');
        context.push('/otp', extra: _fullPhone);
      }
    } catch (e) {
      if (!mounted) return;
      String message = e.toString();
      if (message.contains('Invalid login credentials')) {
        message = 'Invalid email or password. Please try again.';
      } else if (message.contains('Email not confirmed')) {
        message = 'Please confirm your email address before logging in.';
      }
      showSugoBaySnackBar(context, 'Login failed: $message', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeByRole(String? role) async {
    if (role == 'merchant') {
      // Check if merchant is approved
      final userId = SupabaseService.currentUserId;
      final merchant = await SupabaseService.merchants()
          .select('is_approved')
          .eq('user_id', userId!)
          .maybeSingle();

      if (merchant == null || merchant['is_approved'] == false) {
        context.go('/merchant-pending');
        return;
      }
    }

    switch (role) {
      case 'customer':
        context.go('/customer');
        break;
      case 'merchant':
        context.go('/merchant-home');
        break;
      case 'rider':
        context.go('/rider-home');
        break;
      case 'admin':
        _launchAdminPanel();
        break;
      default:
        // If no role, they might need to register
        context.go('/register');
    }
  }

  Future<void> _launchAdminPanel() async {
    final uri = Uri.parse(AppConstants.adminPanelUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    await SupabaseService.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _socialLogin(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.sugobay://login-callback',
      );
      // OAuth redirect will happen, session will be handled on return
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(
        context,
        'Failed to login with ${provider.name}: ${e.toString()}',
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo
                Image.asset('assets/images/logo.png', width: 100, height: 100),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 32,
                    color: AppColors.teal,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.tagline,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),

                // Dynamic Input Field
                if (_isEmailLogin) ...[
                  SugoBayTextField(
                    label: 'Email Address',
                    hint: 'your@email.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(
                      Icons.email_outlined,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SugoBayTextField(
                    label: 'Password',
                    hint: '••••••••',
                    controller: _passwordController,
                    obscureText: true,
                    prefix: const Icon(
                      Icons.lock_outline,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ] else
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
                      final cleaned = value.trim().startsWith('0')
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

                // Primary Login Action
                SugoBayButton(
                  text: _isEmailLogin ? 'Login' : 'Send OTP',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),

                if (!_isEmailLogin) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isEmailLogin = true),
                    child: Text(
                      'Back to Email Login',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.darkGrey)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.darkGrey)),
                  ],
                ),
                const SizedBox(height: 32),

                // Social Logins - Fixed for mobile display
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _SocialButton(
                      icon: Icons.g_mobiledata_rounded,
                      label: 'Google',
                      color: Colors.white,
                      textColor: Colors.black87,
                      onPressed: () => _socialLogin(OAuthProvider.google),
                      width: (MediaQuery.of(context).size.width - 56 - 12) / 2,
                    ),
                    _SocialButton(
                      icon: Icons.facebook,
                      label: 'Facebook',
                      color: const Color(0xFF1877F2),
                      textColor: Colors.white,
                      onPressed: () => _socialLogin(OAuthProvider.facebook),
                      width: (MediaQuery.of(context).size.width - 56 - 12) / 2,
                    ),
                    if (_isEmailLogin)
                      _SocialButton(
                        icon: Icons.phone_android_rounded,
                        label: 'Phone Login',
                        color: AppColors.darkGrey,
                        textColor: Colors.white,
                        onPressed: () => setState(() => _isEmailLogin = false),
                        width: double.infinity, // Phone login on its own row
                      ),
                  ],
                ),

                const SizedBox(height: 48),
                Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
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

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;
  final double? width;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: width,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor, size: 24),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
