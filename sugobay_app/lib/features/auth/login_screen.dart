import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String _loadingMethod = '';
  bool _rememberMe = false;

  // Email form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _showEmailForm = false;
  bool _obscurePassword = true;

  // Phone form
  final _phoneController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();

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

      if (role == 'merchant') {
        final userId = SupabaseService.auth.currentUser!.id;
        final merchantRes = await SupabaseService.client
            .from('merchants')
            .select('is_approved')
            .eq('user_id', userId)
            .maybeSingle();

        if (merchantRes == null || merchantRes['is_approved'] != true) {
          await SupabaseService.auth.signOut();
          if (!mounted) return;
          _showApprovalPendingDialog();
          return;
        }
      }

      if (!mounted) return;
      switch (role) {
        case 'customer':
          context.go('/customer');
          break;
        case 'rider':
          context.go('/rider-home');
          break;
        case 'merchant':
          context.go('/merchant-home');
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

  void _showApprovalPendingDialog() {
    final c = context.sc;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: SColors.gold, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Pending Approval',
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 12),
              Text(
                'Your merchant account is still being reviewed by admin. You will be notified once approved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message, IconData icon, Color color) {
    final c = context.sc;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailNotConfirmedDialog(String email) {
    final c = context.sc;
    bool resending = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: c.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SColors.coral.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.email_outlined, color: SColors.coral, size: 40),
                ),
                const SizedBox(height: 20),
                Text('Email Not Confirmed',
                    style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  'Please confirm your email before signing in. Check your inbox for a confirmation link.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: resending
                        ? null
                        : () async {
                            setDialogState(() => resending = true);
                            try {
                              await SupabaseService.auth.resend(
                                type: OtpType.signup,
                                email: email,
                              );
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                showSugoBaySnackBar(context, 'Confirmation email resent! Check your inbox.');
                              }
                            } catch (e) {
                              setDialogState(() => resending = false);
                              if (ctx.mounted) {
                                showSugoBaySnackBar(context, 'Failed to resend: $e', isError: true);
                              }
                            }
                          },
                    child: resending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Resend Confirmation Email'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Close', style: TextStyle(color: c.textTertiary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    final c = context.sc;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Terms of Service',
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: Text(
                    'Welcome to SugoBay!\n\n'
                    'By using SugoBay, you agree to the following terms:\n\n'
                    '1. Account Responsibility\n'
                    'You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.\n\n'
                    '2. Service Usage\n'
                    'SugoBay provides food delivery and errand services ("Pahapit") within Ubay, Bohol. You agree to use the service only for lawful purposes.\n\n'
                    '3. Orders & Payments\n'
                    'All orders are subject to merchant availability. Prices displayed include the item cost; delivery fees are calculated separately. Payment must be completed as agreed.\n\n'
                    '4. Cancellation & Refunds\n'
                    'Orders may be cancelled before the rider picks up the item. Refund policies depend on the stage of the order.\n\n'
                    '5. Rider & Merchant Terms\n'
                    'Riders and merchants must comply with SugoBay operational guidelines. Merchant accounts require admin approval before activation.\n\n'
                    '6. Privacy\n'
                    'We collect and use your personal data (name, email, phone, location) to provide and improve our services. Your data is stored securely and not shared with third parties without consent.\n\n'
                    '7. Limitation of Liability\n'
                    'SugoBay acts as a platform connecting customers, merchants, and riders. We are not liable for the quality of food or items delivered.\n\n'
                    '8. Changes\n'
                    'We may update these terms at any time. Continued use of the app constitutes acceptance of the updated terms.\n\n'
                    'For questions, contact us through the app.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    final c = context.sc;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 140, fit: BoxFit.contain),
              const SizedBox(height: 16),
              Text('Version ${AppConstants.version}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary)),
              const SizedBox(height: 20),
              Text(
                'SugoBay is a food delivery and errand service platform built for the people of Ubay, Bohol. '
                'Order food from local merchants or request "Pahapit" errands — we\'ll handle the rest!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('Developed by',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary)),
                    const SizedBox(height: 4),
                    Text('Jecu Cutanda',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: SColors.gold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  // ─── Email Sign In ─────────────────────────────────────────────────

  Future<void> _signInWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingMethod = 'email';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );

      await _handleAuthSuccess();
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('not found')) {
        showSugoBaySnackBar(context, 'No account found. Please sign up first.', isError: true);
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        final email = _emailController.text.trim();
        String? role;
        bool? isApproved;

        try {
          final res = await SupabaseService.client
              .rpc('get_role_by_email', params: {'lookup_email': email});
          if (res is Map) {
            role = res['role'] as String?;
            isApproved = res['is_approved'] as bool?;
          } else if (res is String) {
            role = res;
          }
        } catch (_) {}

        if (!mounted) return;
        if (role == 'merchant') {
          if (isApproved == true) {
            _showErrorDialog(
              'Account Issue',
              'Your merchant account is approved but there was a sign-in issue. Please contact support or try again.',
              Icons.warning_amber_rounded,
              SColors.gold,
            );
          } else {
            _showApprovalPendingDialog();
          }
        } else {
          _showEmailNotConfirmedDialog(email);
        }
      } else {
        showSugoBaySnackBar(context, e.message, isError: true);
      }
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
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/landing'),
                    icon: Icon(Icons.arrow_back, color: c.textPrimary),
                    padding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 24),

                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  width: 160,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Login to Your Account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 32),

                // ─── Phone Input ─────────────────────────────────
                if (!_showEmailForm)
                  Form(
                    key: _phoneFormKey,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: c.inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              // Country code
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🇵🇭', style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down, size: 18, color: c.textSecondary),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 28, color: c.border),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '+63 9XX XXX XXXX',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      color: c.textTertiary,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Phone number required';
                                    final cleaned = value.trim().startsWith('0')
                                        ? value.trim().substring(1)
                                        : value.trim();
                                    if (cleaned.length != 10 || !RegExp(r'^\d{10}$').hasMatch(cleaned)) {
                                      return 'Enter a valid 10-digit phone number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Remember me
                        GestureDetector(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _rememberMe ? SColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _rememberMe ? SColors.primary : c.border,
                                    width: 2,
                                  ),
                                ),
                                child: _rememberMe
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Remember me',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sign In button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendPhoneOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: SColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: (_isLoading && _loadingMethod == 'phone')
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'Sign in',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Email Form ──────────────────────────────────
                if (_showEmailForm)
                  Form(
                    key: _emailFormKey,
                    child: Column(
                      children: [
                        // Email input
                        Container(
                          decoration: BoxDecoration(
                            color: c.inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textTertiary),
                              prefixIcon: Icon(Icons.email_outlined, color: c.textTertiary, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email required';
                              if (!v.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Password input
                        Container(
                          decoration: BoxDecoration(
                            color: c.inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textCapitalization: TextCapitalization.none,
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textTertiary),
                              prefixIcon: Icon(Icons.lock_outline, color: c.textTertiary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: c.textTertiary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Password required';
                              if (v.length < 6) return 'Min 6 characters';
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Forgot password + Remember me row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _rememberMe ? SColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _rememberMe ? SColors.primary : c.border,
                                        width: 2,
                                      ),
                                    ),
                                    child: _rememberMe
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Remember me',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textPrimary)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/forgot-password'),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: SColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sign In button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signInWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: SColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: (_isLoading && _loadingMethod == 'email')
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'Sign in',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 28),

                // ─── Divider ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: c.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or continue with',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary),
                      ),
                    ),
                    Expanded(child: Divider(color: c.divider)),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── Social Icons Row ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialIconButton(
                      icon: Icons.facebook_rounded,
                      color: const Color(0xFF1877F2),
                      isLoading: _isLoading && _loadingMethod == 'facebook',
                      onTap: _isLoading ? null : _signInWithFacebook,
                      c: c,
                    ),
                    const SizedBox(width: 16),
                    _socialIconButton(
                      customChild: SizedBox(
                        width: 22, height: 22,
                        child: CustomPaint(painter: _GoogleLogoPainter()),
                      ),
                      isLoading: _isLoading && _loadingMethod == 'google',
                      onTap: _isLoading ? null : _signInWithGoogle,
                      c: c,
                    ),
                    const SizedBox(width: 16),
                    _socialIconButton(
                      icon: _showEmailForm ? Icons.phone_rounded : Icons.email_rounded,
                      color: c.textPrimary,
                      isLoading: false,
                      onTap: _isLoading
                          ? null
                          : () => setState(() {
                                _showEmailForm = !_showEmailForm;
                              }),
                      c: c,
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ─── Sign Up Link ────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?  ",
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: Text(
                        'Sign up',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ─── Terms & About ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _showTermsDialog,
                      child: Text(
                        'Terms of Service',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: SColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: SColors.primary,
                        ),
                      ),
                    ),
                    Text('  •  ',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary)),
                    GestureDetector(
                      onTap: _showAboutDialog,
                      child: Text(
                        'About',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: SColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: SColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Text(
                  'Powered by Jecu Cutanda',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: c.textTertiary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${AppConstants.version}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: c.textTertiary),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialIconButton({
    IconData? icon,
    Color? color,
    Widget? customChild,
    required bool isLoading,
    required VoidCallback? onTap,
    required SugoColors c,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                )
              : customChild ?? Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}

// Custom painter for the Google "G" logo with proper brand colors
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w * 0.45;

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.9, 1.8, false, bluePaint,
    );

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.9, 1.2, false, greenPaint,
    );

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.1, 1.0, false, yellowPaint,
    );

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.1, 1.35, false, redPaint,
    );

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(cx, cy - w * 0.08, r + w * 0.05, w * 0.16),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
