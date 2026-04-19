import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

/// Profile setup screen shown after first login (any provider).
/// Collects phone number (required for delivery contact) and role.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedRole = 'customer';
  String _selectedCategory = 'restaurant';
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    _prefillFromAuth();
  }

  Future<void> _prefillFromAuth() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Pre-fill name from Google/Facebook metadata
    final meta = user.userMetadata;
    final name = meta?['full_name'] ?? meta?['name'] ?? '';
    if (name.isNotEmpty) {
      _nameController.text = name;
    }

    // Pre-fill phone if signed in via phone
    final phone = user.phone;
    if (phone != null && phone.isNotEmpty) {
      // Strip +63 prefix for display
      _phoneController.text =
          phone.startsWith('+63') ? phone.substring(3) : phone;
    }

    // Check if profile already has some data
    final profile = await SupabaseService.getUserProfile();
    if (profile != null && mounted) {
      if (profile['name'] != null && profile['name'] != 'New User') {
        _nameController.text = profile['name'];
      }
      if (profile['phone'] != null) {
        final p = profile['phone'] as String;
        _phoneController.text = p.startsWith('+63') ? p.substring(3) : p;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    final cleaned = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+63$cleaned';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        showSugoBaySnackBar(context, 'Session expired. Please login again.',
            isError: true);
        context.go('/login');
        return;
      }

      // Upsert user profile (handle_new_user trigger may have created a row)
      await SupabaseService.users().upsert({
        'id': userId,
        'name': _nameController.text.trim(),
        'phone': _fullPhone,
        'role': _selectedRole,
        'email': SupabaseService.currentUser?.email,
      });

      // If merchant, insert merchant record
      if (_selectedRole == 'merchant') {
        await SupabaseService.merchants().insert({
          'user_id': userId,
          'shop_name': _shopNameController.text.trim(),
          'address': _addressController.text.trim(),
          'category': _selectedCategory,
          'lat': AppConstants.defaultMapCenter.latitude,
          'lng': AppConstants.defaultMapCenter.longitude,
          'is_approved': false,
        });

        if (!mounted) return;
        await _showApprovalDialog();
      }

      if (!mounted) return;
      _routeByRole(_selectedRole);
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(
        context,
        'Registration failed: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showApprovalDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Icon(
          Icons.hourglass_top_rounded,
          color: AppColors.gold,
          size: 48,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Waiting for Admin Approval',
              style: AppTextStyles.subheading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your merchant account has been submitted. '
              'You will be notified once approved.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK',
                style: AppTextStyles.button.copyWith(color: AppColors.teal)),
          ),
        ],
      ),
    );
  }

  void _routeByRole(String role) {
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
        context.go('/login');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Complete Your Profile', style: AppTextStyles.subheading),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We need a few details to get you started',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 24),

                // Name
                SugoBayTextField(
                  label: 'Full Name',
                  hint: 'Enter your name',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone (always required)
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
                      return 'Phone number is required for delivery contact';
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
                const SizedBox(height: 24),

                // Role selector
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
                const SizedBox(height: 28),

                // Merchant-specific fields
                if (_selectedRole == 'merchant') ...[
                  SugoBayTextField(
                    label: 'Shop Name',
                    hint: 'Enter your shop name',
                    controller: _shopNameController,
                    validator: (v) {
                      if (_selectedRole == 'merchant' &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Shop name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SugoBayTextField(
                    label: 'Shop Address',
                    hint: 'Enter your shop address',
                    controller: _addressController,
                    validator: (v) {
                      if (_selectedRole == 'merchant' &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
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
                        icon: const Icon(Icons.arrow_drop_down,
                            color: AppColors.gold),
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
                  const SizedBox(height: 28),
                ],

                // Submit button
                SugoBayButton(
                  text: _selectedRole == 'merchant'
                      ? 'Submit for Approval'
                      : 'Complete Setup',
                  onPressed: _saveProfile,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
