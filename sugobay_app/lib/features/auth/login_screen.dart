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

      // Check merchant approval status before allowing access
      if (role == 'merchant') {
        final userId = SupabaseService.auth.currentUser!.id;
        final merchantRes = await SupabaseService.client
            .from('merchants')
            .select('is_approved')
            .eq('user_id', userId)
            .maybeSingle();

        if (merchantRes == null || merchantRes['is_approved'] != true) {
          // Sign them out — they can't access the app yet
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Pending Approval',
                style: AppTextStyles.heading.copyWith(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Your merchant account is still being reviewed by admin. You will be notified once approved.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.grey[400], height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
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
              Text(
                title,
                style: AppTextStyles.heading.copyWith(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.grey[400], height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Terms of Service ────────────────────────────────────────────

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms of Service',
                style: AppTextStyles.heading.copyWith(fontSize: 20, color: Colors.white),
              ),
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
                    style: AppTextStyles.body.copyWith(color: Colors.grey[400], height: 1.6, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── About ──────────────────────────────────────────────────────

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 140, fit: BoxFit.contain),
              const SizedBox(height: 16),
              Text(
                'Version ${AppConstants.version}',
                style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              Text(
                'SugoBay is a food delivery and errand service platform built for the people of Ubay, Bohol. '
                'Order food from local merchants or request "Pahapit" errands — we\'ll handle the rest!',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.grey[400], height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Developed by',
                      style: AppTextStyles.caption.copyWith(color: Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jecu Cutanda',
                      style: AppTextStyles.subheading.copyWith(
                        color: AppColors.gold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
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
        showSugoBaySnackBar(
          context,
          'No account found. Please sign up first.',
          isError: true,
        );
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        // Check if this is a merchant via an RPC function (bypasses RLS)
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
            // Old function format — just role string
            role = res;
          }
        } catch (_) {
          // Function may not exist yet — fall through
        }

        if (!mounted) return;
        if (role == 'merchant') {
          if (isApproved == true) {
            // Merchant is approved but email still not confirmed —
            // this shouldn't happen after admin fix, but handle gracefully
            _showErrorDialog(
              'Account Issue',
              'Your merchant account is approved but there was a sign-in issue. Please contact support or try again.',
              Icons.warning_amber_rounded,
              AppColors.gold,
            );
          } else {
            _showApprovalPendingDialog();
          }
        } else {
          _showErrorDialog(
            'Email Not Confirmed',
            'Please confirm your email before signing in. Check your inbox for a confirmation link.',
            Icons.email_outlined,
            AppColors.coral,
          );
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
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            children: [
              const SizedBox(height: 30),
              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),

              // ─── Social Buttons ─────────────────────────────────
              _buildGoogleButton(),
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
                        textCapitalization: TextCapitalization.none,
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
                        textCapitalization: TextCapitalization.none,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Password required';
                          if (v.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SugoBayButton(
                        text: 'Sign In',
                        onPressed: _signInWithEmail,
                        isLoading: _isLoading && _loadingMethod == 'email',
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
                        textCapitalization: TextCapitalization.none,
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

              const SizedBox(height: 20),

              // ─── Sign Up Link ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTextStyles.caption,
                  ),
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: Text(
                      'Sign Up',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ─── Terms & About ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showTermsDialog(),
                    child: Text(
                      'Terms of Service',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.teal,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.teal,
                      ),
                    ),
                  ),
                  Text('  •  ', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  GestureDetector(
                    onTap: () => _showAboutDialog(),
                    child: Text(
                      'About',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.teal,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                'Powered by Jecu Cutanda',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: Colors.white30,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v${AppConstants.version}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Google Button with proper "G" logo ─────────────────────────
  Widget _buildGoogleButton() {
    final isLoading = _isLoading && _loadingMethod == 'google';
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black87,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Custom Google "G" logo
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GoogleLogoPainter()),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                ],
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

    // Blue arc (top-right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.9, // start angle
      1.8,  // sweep angle
      false,
      bluePaint,
    );

    // Green arc (bottom-right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.9,
      1.2,
      false,
      greenPaint,
    );

    // Yellow arc (bottom-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.1,
      1.0,
      false,
      yellowPaint,
    );

    // Red arc (top-left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.1,
      1.35,
      false,
      redPaint,
    );

    // Horizontal bar of the "G"
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
