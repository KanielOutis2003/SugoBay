import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class RegisterScreen extends StatefulWidget {
  final String phone;

  const RegisterScreen({super.key, required this.phone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
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

      // Insert user record
      await SupabaseService.users().insert({
        'id': userId,
        'name': _nameController.text.trim(),
        'phone': widget.phone,
        'role': _selectedRole,
      });

      // If merchant, insert merchant record
      if (_selectedRole == 'merchant') {
        await SupabaseService.merchants().insert({
          'user_id': userId,
          'shop_name': _shopNameController.text.trim(),
          'address': _addressController.text.trim(),
          'category': _selectedCategory,
          'lat': 0.0,
          'lng': 0.0,
          'is_approved': false,
        });

        if (!mounted) return;

        // Show waiting for approval dialog
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
                  'Your merchant account has been submitted and is pending approval. '
                  'You will be notified once an admin reviews your application.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'OK',
                  style: AppTextStyles.button.copyWith(color: AppColors.teal),
                ),
              ),
            ],
          ),
        );
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
        title: Text('Create Account', style: AppTextStyles.subheading),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                SugoBayTextField(
                  label: 'Full Name',
                  hint: 'Enter your name',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
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
                    validator: (value) {
                      if (_selectedRole == 'merchant' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Shop name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  SugoBayTextField(
                    label: 'Address',
                    hint: 'Enter your shop address',
                    controller: _addressController,
                    validator: (value) {
                      if (_selectedRole == 'merchant' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category dropdown
                  Text(
                    'Category',
                    style:
                        AppTextStyles.body.copyWith(color: AppColors.gold),
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

                // Register button
                SugoBayButton(
                  text: _selectedRole == 'merchant'
                      ? 'Submit for Approval'
                      : 'Create Account',
                  onPressed: _register,
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
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
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
