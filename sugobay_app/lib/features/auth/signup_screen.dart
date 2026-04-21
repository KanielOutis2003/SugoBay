import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
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
  String? _successType; // 'email_confirm' or 'merchant_pending'

  // Location autocomplete
  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounceTimer;
  double? _selectedLat;
  double? _selectedLng;

  static const List<String> _merchantCategories = [
    'restaurant',
    'carenderia',
    'fastfood',
    'bbq',
    'bakery',
    'cafe',
    'other_food',
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
      final response = await http.get(uri, headers: {
        'User-Agent': 'SugoBayApp/1.0',
      });
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
    } catch (_) {
      // Silently fail — user can still type manually
    }
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

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final phone = _fullPhone;

      // Build metadata — trigger handles user + merchant creation
      final metadata = <String, dynamic>{
        'full_name': name,
        'phone': phone,
        'role': _selectedRole,
      };

      // Add merchant details to metadata so the trigger creates the record
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
      if (userId == null) {
        throw Exception('Failed to create account');
      }

      if (!mounted) return;

      if (_selectedRole == 'merchant') {
        // Sign out merchant — they wait for admin approval
        await SupabaseService.auth.signOut();
        setState(() => _successType = 'merchant_pending');
      } else {
        // Customer/Rider — need to confirm email
        await SupabaseService.auth.signOut();
        setState(() => _successType = 'email_confirm');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('already registered')) {
        showSugoBaySnackBar(
          context,
          'This email is already registered. Please sign in.',
          isError: true,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: _successType == null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.white),
                onPressed: () => context.go('/login'),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: _successType != null
              ? _buildSuccessView()
              : _buildSignupForm(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final isMerchant = _successType == 'merchant_pending';

    return Column(
      children: [
        const SizedBox(height: 60),
        Icon(
          isMerchant ? Icons.hourglass_top_rounded : Icons.mark_email_read_rounded,
          color: isMerchant ? AppColors.gold : AppColors.teal,
          size: 80,
        ),
        const SizedBox(height: 24),
        Text(
          isMerchant ? 'Application Submitted' : 'Check Your Email',
          style: AppTextStyles.heading.copyWith(
            fontSize: 24,
            color: isMerchant ? AppColors.gold : AppColors.teal,
          ),
        ),
        const SizedBox(height: 16),
        if (isMerchant) ...[
          Text(
            'Your merchant account for',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _shopNameController.text.trim(),
            style: AppTextStyles.body.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'has been submitted and is pending admin approval. '
            'You will be notified once your application is reviewed.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            'We sent a confirmation link to',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _emailController.text.trim(),
            style: AppTextStyles.body.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Please confirm your email before signing in.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 40),
        SugoBayButton(
          text: 'Go to Sign In',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 80, height: 80),
                const SizedBox(height: 16),
                Text(
                  'Create Account',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 24,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your role and fill in your details',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── Role Selection ─────────────────────────────────
          Text(
            'I want to be a...',
            style: AppTextStyles.body.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRoleCard(
                role: 'customer',
                label: 'Customer',
                icon: Icons.shopping_bag_rounded,
              ),
              const SizedBox(width: 10),
              _buildRoleCard(
                role: 'rider',
                label: 'Rider',
                icon: Icons.delivery_dining_rounded,
              ),
              const SizedBox(width: 10),
              _buildRoleCard(
                role: 'merchant',
                label: 'Merchant',
                icon: Icons.storefront_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Common Fields ──────────────────────────────────
          SugoBayTextField(
            label: 'Full Name',
            hint: 'Enter your name',
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              return null;
            },
          ),
          const SizedBox(height: 12),
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone number required';
              final cleaned =
                  v.trim().startsWith('0') ? v.trim().substring(1) : v.trim();
              if (cleaned.length != 10 ||
                  !RegExp(r'^\d{10}$').hasMatch(cleaned)) {
                return 'Enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          SugoBayTextField(
            label: 'Password',
            hint: 'Min 6 characters',
            controller: _passwordController,
            obscureText: true,
            textCapitalization: TextCapitalization.none,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password required';
              if (v.length < 6) return 'Min 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          SugoBayTextField(
            label: 'Confirm Password',
            hint: 'Re-enter password',
            controller: _confirmPasswordController,
            obscureText: true,
            textCapitalization: TextCapitalization.none,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          // ─── Merchant-Specific Fields ───────────────────────
          if (_selectedRole == 'merchant') ...[
            const SizedBox(height: 20),
            Divider(color: AppColors.darkGrey),
            const SizedBox(height: 12),
            Text(
              'Shop Details',
              style: AppTextStyles.subheading.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: 12),
            SugoBayTextField(
              label: 'Shop Name',
              hint: 'Enter your shop name',
              controller: _shopNameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (_selectedRole == 'merchant' &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Shop name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SugoBayTextField(
              label: 'Shop Address',
              hint: 'Start typing to search location...',
              controller: _addressController,
              textCapitalization: TextCapitalization.words,
              onChanged: _onAddressChanged,
              validator: (v) {
                if (_selectedRole == 'merchant' &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Address is required';
                }
                return null;
              },
            ),
            // Location suggestions dropdown
            if (_locationSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.teal),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _locationSuggestions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: AppColors.darkGrey, height: 1),
                  itemBuilder: (context, index) {
                    final loc = _locationSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on,
                          color: AppColors.teal, size: 20),
                      title: Text(
                        loc['display'] as String,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectLocation(loc),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Category',
              style: AppTextStyles.body.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkGrey),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: AppColors.cardBg,
                  isExpanded: true,
                  style: const TextStyle(color: AppColors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold),
                  items: _merchantCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(
                        _formatCategory(cat),
                        style: const TextStyle(color: AppColors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ─── Submit Button ──────────────────────────────────
          SugoBayButton(
            text: _selectedRole == 'merchant'
                ? 'Submit for Approval'
                : 'Sign Up',
            onPressed: _signUp,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                'Already have an account? Sign In',
                style: AppTextStyles.caption.copyWith(color: AppColors.teal),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.teal.withAlpha(30)
                : AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.teal : AppColors.darkGrey,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? AppColors.teal : AppColors.white,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? AppColors.teal : AppColors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCategory(String category) {
    switch (category) {
      case 'other_food':
        return 'Other Food';
      case 'bbq':
        return 'BBQ';
      case 'fastfood':
        return 'Fast Food';
      default:
        return category[0].toUpperCase() + category.substring(1);
    }
  }
}
