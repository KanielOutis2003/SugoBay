import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String _loadingMethod = '';

  // Email form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _showEmailForm = false;
  bool _isSignUp = false;

  // Phone form
  final _phoneController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  bool _showPhoneForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    final cleaned = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+63$cleaned';
  }

  Future<void> _handleAuthSuccess() async {
    if (!mounted) return;
    try {
      final profile = await SupabaseService.getUserProfile();
      if (!mounted) return;

      if (profile == null || profile['role'] == null || profile['phone'] == null) {
        context.go('/profile-setup');
        return;
      }

      final role = profile['role'] as String;
      final isApproved = profile['is_approved'] as bool? ?? true;

      switch (role) {
        case 'customer':
          context.go('/customer');
          break;
        case 'rider':
          context.go('/rider-home');
          break;
        case 'merchant':
          if (isApproved) {
            context.go('/merchant-home');
          } else {
            context.go('/merchant-home');
          }
          break;
        case 'admin':
          context.go('/');
          break;
        default:
          context.go('/profile-setup');
      }
    } catch (e) {
      if (!mounted) return;
      context.go('/profile-setup');
    }
  }

  // ─── Google Sign In ───────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _loadingMethod = 'google';
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConstants.googleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Google sign in failed: no ID token');
      }

      await SupabaseService.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      await _handleAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Google sign in failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Facebook Sign In ─────────────────────────────────────────────

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isLoading = true;
      _loadingMethod = 'facebook';
    });

    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final accessToken = result.accessToken?.token;
      if (accessToken == null) {
        throw Exception('Facebook login failed: no access token');
      }

      await SupabaseService.auth.signInWithIdToken(
        provider: OAuthProvider.facebook,
        idToken: accessToken,
      );

      await _handleAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Facebook sign in failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Email Sign In / Sign Up ──────────────────────────────────────

  Future<void> _signInWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingMethod = 'email';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        await SupabaseService.auth.signUp(
          email: email,
          password: password,
        );
        if (!mounted) return;
        showSugoBaySnackBar(context, 'Account created! Check email for verification.');
      } else {
        await SupabaseService.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      await _handleAuthSuccess();
    } on AuthException catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Phone OTP ────────────────────────────────────────────────────

  Future<void> _sendPhoneOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingMethod = 'phone';
    });

    try {
      await SupabaseService.auth.signInWithOtp(phone: _fullPhone);
      if (!mounted) return;
      showSugoBaySnackBar(context, 'OTP sent to $_fullPhone');
      context.push('/otp', extra: _fullPhone);
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Failed to send OTP: $e', isError: true);
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
          child: Column(
            children: [
              const SizedBox(height: 30),
              // Logo
              Image.asset('assets/images/logo.png', width: 120, height: 120),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 28,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 6),
              Text(AppConstants.tagline, style: AppTextStyles.caption),
              const SizedBox(height: 40),

              // ─── Social Buttons ─────────────────────────────────
              _buildSocialButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                color: Colors.white,
                textColor: Colors.black87,
                isLoading: _isLoading && _loadingMethod == 'google',
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 12),
              _buildSocialButton(
                label: 'Continue with Facebook',
                icon: Icons.facebook_rounded,
                color: const Color(0xFF1877F2),
                textColor: Colors.white,
                isLoading: _isLoading && _loadingMethod == 'facebook',
                onPressed: _isLoading ? null : _signInWithFacebook,
              ),
              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.darkGrey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: AppTextStyles.caption),
                  ),
                  Expanded(child: Divider(color: AppColors.darkGrey)),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Email Section ──────────────────────────────────
              if (!_showEmailForm)
                _buildSocialButton(
                  label: 'Continue with Email',
                  icon: Icons.email_rounded,
                  color: AppColors.cardBg,
                  textColor: Colors.white,
                  borderColor: AppColors.darkGrey,
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _showEmailForm = true;
                            _showPhoneForm = false;
                          }),
                ),

              if (_showEmailForm)
                Form(
                  key: _emailFormKey,
                  child: Column(
                    children: [
                      SugoBayTextField(
                        label: 'Email',
                        hint: 'you@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SugoBayTextField(
                        label: 'Password',
                        hint: 'Enter password',
                        controller: _passwordController,
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Password required';
                          if (v.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SugoBayButton(
                        text: _isSignUp ? 'Sign Up' : 'Sign In',
                        onPressed: _signInWithEmail,
                        isLoading: _isLoading && _loadingMethod == 'email',
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign In'
                              : "Don't have an account? Sign Up",
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_showEmailForm) const SizedBox(height: 12),

              // ─── Phone Section ──────────────────────────────────
              if (!_showPhoneForm && !_showEmailForm)
                _buildSocialButton(
                  label: 'Continue with Phone',
                  icon: Icons.phone_rounded,
                  color: AppColors.cardBg,
                  textColor: Colors.white,
                  borderColor: AppColors.darkGrey,
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _showPhoneForm = true;
                            _showEmailForm = false;
                          }),
                ),

              if (_showPhoneForm)
                Form(
                  key: _phoneFormKey,
                  child: Column(
                    children: [
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
                            return 'Phone number required';
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
                      const SizedBox(height: 16),
                      SugoBayButton(
                        text: 'Send OTP',
                        onPressed: _sendPhoneOtp,
                        isLoading: _isLoading && _loadingMethod == 'phone',
                      ),
                    ],
                  ),
                ),

              // Back button when showing forms
              if (_showEmailForm || _showPhoneForm)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _showEmailForm = false;
                      _showPhoneForm = false;
                    }),
                    child: Text(
                      'Back to all options',
                      style: AppTextStyles.caption.copyWith(color: AppColors.coral),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              Text(
                'By continuing, you agree to our Terms of Service',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    Color? borderColor,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor != null
                ? BorderSide(color: borderColor)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 10),
                  Text(label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
      ),
    );
  }
}
