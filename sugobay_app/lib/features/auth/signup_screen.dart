import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedRole = 'customer';
  String _selectedCategory = 'restaurant';
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _successType;
  String _loadingMethod = '';

  // Location autocomplete
  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounceTimer;
  double? _selectedLat;
  double? _selectedLng;

  static const List<String> _merchantCategories = [
    'restaurant', 'carenderia', 'fastfood', 'bbq', 'bakery', 'cafe', 'other_food',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onAddressChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() => _locationSuggestions = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchLocations(query.trim());
    });
  }

  Future<void> _searchLocations(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)},Ubay,Bohol,Philippines'
        '&format=json&limit=5&addressdetails=1',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'SugoBayApp/1.0'});
      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (mounted) {
          setState(() {
            _locationSuggestions = results
                .map((r) => {
                      'display': r['display_name'] as String,
                      'lat': double.tryParse(r['lat'] ?? '') ?? 0.0,
                      'lng': double.tryParse(r['lon'] ?? '') ?? 0.0,
                    })
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  void _selectLocation(Map<String, dynamic> location) {
    _addressController.text = location['display'] as String;
    setState(() {
      _selectedLat = location['lat'] as double;
      _selectedLng = location['lng'] as double;
      _locationSuggestions = [];
    });
  }

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    final cleaned = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+63$cleaned';
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingMethod = 'signup';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final phone = _fullPhone;

      final metadata = <String, dynamic>{
        'full_name': name,
        'phone': phone,
        'role': _selectedRole,
      };

      if (_selectedRole == 'merchant') {
        metadata['shop_name'] = _shopNameController.text.trim();
        metadata['shop_address'] = _addressController.text.trim();
        metadata['shop_category'] = _selectedCategory;
        metadata['shop_lat'] = (_selectedLat ?? 0.0).toString();
        metadata['shop_lng'] = (_selectedLng ?? 0.0).toString();
      }

      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      final userId = response.user?.id;
      if (userId == null) throw Exception('Failed to create account');

      if (!mounted) return;

      if (_selectedRole == 'merchant') {
        await SupabaseService.auth.signOut();
        setState(() => _successType = 'merchant_pending');
      } else {
        await SupabaseService.auth.signOut();
        setState(() => _successType = 'email_confirm');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('already registered')) {
        showSugoBaySnackBar(context, 'This email is already registered. Please sign in.', isError: true);
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

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
      _loadingMethod = 'google';
    });
    try {
      final googleSignIn = GoogleSignIn(serverClientId: AppConstants.googleWebClientId);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('Google sign in failed: no ID token');

      await SupabaseService.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (!mounted) return;
      await _navigateAfterSocialAuth();
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Google sign up failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithFacebook() async {
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
      if (accessToken == null) throw Exception('Facebook login failed: no access token');

      await SupabaseService.auth.signInWithIdToken(
        provider: OAuthProvider.facebook,
        idToken: accessToken,
      );

      if (!mounted) return;
      await _navigateAfterSocialAuth();
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Facebook sign up failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterSocialAuth() async {
    final profile = await SupabaseService.getUserProfile();
    if (!mounted) return;
    if (profile == null || profile['role'] == null) {
      context.go('/profile-setup');
    } else {
      final role = profile['role'] as String;
      switch (role) {
        case 'customer': context.go('/customer'); break;
        case 'rider': context.go('/rider-home'); break;
        case 'merchant': context.go('/merchant-home'); break;
        default: context.go('/profile-setup');
      }
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
            child: _successType != null
                ? _buildSuccessView(c)
                : _buildSignupForm(c),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(SugoColors c) {
    final isMerchant = _successType == 'merchant_pending';

    return Column(
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isMerchant ? SColors.gold : SColors.primary).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isMerchant ? Icons.hourglass_top_rounded : Icons.mark_email_read_rounded,
            color: isMerchant ? SColors.gold : SColors.primary,
            size: 64,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          isMerchant ? 'Application Submitted' : 'Check Your Email',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (isMerchant) ...[
          Text('Your merchant account for',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_shopNameController.text.trim(),
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: SColors.gold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'has been submitted and is pending admin approval. You will be notified once your application is reviewed.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text('We sent a confirmation link to',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_emailController.text.trim(),
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: SColors.primary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text('Please confirm your email before signing in.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: Text('Go to Sign In',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSignupForm(SugoColors c) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
              icon: Icon(Icons.arrow_back, color: c.textPrimary),
              padding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 16),

          // Logo
          Center(
            child: Image.asset('assets/images/logo.png', width: 120, fit: BoxFit.contain),
          ),

          const SizedBox(height: 24),

          // Title
          Center(
            child: Text(
              'Create New Account',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ─── Role Selection ─────────────────────────────────
          Text('I want to be a...',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRoleCard(role: 'customer', label: 'Customer', icon: Icons.shopping_bag_rounded, c: c),
              const SizedBox(width: 10),
              _buildRoleCard(role: 'rider', label: 'Rider', icon: Icons.delivery_dining_rounded, c: c),
              const SizedBox(width: 10),
              _buildRoleCard(role: 'merchant', label: 'Merchant', icon: Icons.storefront_rounded, c: c),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Phone Input ─────────────────────────────────
          _buildInputField(
            controller: _phoneController,
            hint: '+63 9XX XXX XXXX',
            keyboardType: TextInputType.phone,
            c: c,
            prefix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14),
                const Text('🇵🇭', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 16, color: c.textSecondary),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: c.border),
                const SizedBox(width: 8),
              ],
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone number required';
              final cleaned = v.trim().startsWith('0') ? v.trim().substring(1) : v.trim();
              if (cleaned.length != 10 || !RegExp(r'^\d{10}$').hasMatch(cleaned)) {
                return 'Enter a valid 10-digit phone number';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // ─── Email Input ─────────────────────────────────
          _buildInputField(
            controller: _emailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            c: c,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),

          const SizedBox(height: 12),

          // ─── Full Name ─────────────────────────────────
          _buildInputField(
            controller: _nameController,
            hint: 'Full Name',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            c: c,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              return null;
            },
          ),

          const SizedBox(height: 12),

          // ─── Password ─────────────────────────────────
          _buildInputField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            c: c,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: c.textTertiary, size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password required';
              if (v.length < 6) return 'Min 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 12),

          // ─── Confirm Password ─────────────────────────────────
          _buildInputField(
            controller: _confirmPasswordController,
            hint: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            c: c,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: c.textTertiary, size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          // ─── Merchant-Specific Fields ───────────────────────
          if (_selectedRole == 'merchant') ...[
            const SizedBox(height: 20),
            Divider(color: c.divider),
            const SizedBox(height: 12),
            Text('Shop Details',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: SColors.primary)),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _shopNameController,
              hint: 'Shop Name',
              icon: Icons.storefront_outlined,
              textCapitalization: TextCapitalization.words,
              c: c,
              validator: (v) {
                if (_selectedRole == 'merchant' && (v == null || v.trim().isEmpty)) return 'Shop name is required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _addressController,
              hint: 'Shop Address',
              icon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.words,
              c: c,
              onChanged: _onAddressChanged,
              validator: (v) {
                if (_selectedRole == 'merchant' && (v == null || v.trim().isEmpty)) return 'Address is required';
                return null;
              },
            ),
            if (_locationSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SColors.primary),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _locationSuggestions.length,
                  separatorBuilder: (_, __) => Divider(color: c.divider, height: 1),
                  itemBuilder: (context, index) {
                    final loc = _locationSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, color: SColors.primary, size: 20),
                      title: Text(
                        loc['display'] as String,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectLocation(loc),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text('Category',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: c.cardBg,
                  isExpanded: true,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textPrimary),
                  icon: Icon(Icons.arrow_drop_down, color: SColors.primary),
                  items: _merchantCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(_formatCategory(cat),
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedCategory = value);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

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
                  child: _rememberMe ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 10),
                Text('Remember me',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Sign Up Button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: SColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: SColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: (_isLoading && _loadingMethod == 'signup')
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selectedRole == 'merchant' ? 'Submit for Approval' : 'Sign up',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 28),

          // ─── Divider ─────────────────────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: c.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('or continue with',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary)),
              ),
              Expanded(child: Divider(color: c.divider)),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Social Icons ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialIconButton(
                icon: Icons.facebook_rounded,
                color: const Color(0xFF1877F2),
                isLoading: _isLoading && _loadingMethod == 'facebook',
                onTap: _isLoading ? null : _signUpWithFacebook,
                c: c,
              ),
              const SizedBox(width: 16),
              _socialIconButton(
                customChild: SizedBox(
                  width: 22, height: 22,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                isLoading: _isLoading && _loadingMethod == 'google',
                onTap: _isLoading ? null : _signUpWithGoogle,
                c: c,
              ),
              const SizedBox(width: 16),
              _socialIconButton(
                icon: Icons.email_rounded,
                color: c.textPrimary,
                isLoading: false,
                onTap: null,
                c: c,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ─── Sign In Link ────────────────────────────────
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Already have an account?  ",
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text('Sign in',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700, color: SColors.primary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required SugoColors c,
    IconData? icon,
    Widget? prefix,
    Widget? suffix,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textTertiary),
          prefixIcon: prefix ?? (icon != null ? Icon(icon, color: c.textTertiary, size: 20) : null),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String label,
    required IconData icon,
    required SugoColors c,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? SColors.primary.withValues(alpha: 0.1) : c.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? SColors.primary : c.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: isSelected ? SColors.primary : c.textSecondary),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isSelected ? SColors.primary : c.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
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
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary))
              : customChild ?? Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  String _formatCategory(String category) {
    switch (category) {
      case 'other_food': return 'Other Food';
      case 'bbq': return 'BBQ';
      case 'fastfood': return 'Fast Food';
      default: return category[0].toUpperCase() + category.substring(1);
    }
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double cx = w / 2;
    final double cy = size.height / 2;
    final double r = w * 0.45;
    final sw = w * 0.18;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.9, 1.8, false, Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = sw);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        0.9, 1.2, false, Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = sw);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.1, 1.0, false, Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = sw);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.1, 1.35, false, Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = sw);
    canvas.drawRect(Rect.fromLTWH(cx, cy - w * 0.08, r + w * 0.05, w * 0.16),
        Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
