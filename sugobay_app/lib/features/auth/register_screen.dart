import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class RegisterScreen extends StatefulWidget {
  final String? identifier;

  const RegisterScreen({super.key, this.identifier});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    if (widget.identifier != null) {
      if (widget.identifier!.contains('@')) {
        _emailController.text = widget.identifier!;
      } else if (RegExp(r'^\+?\d+$').hasMatch(widget.identifier!)) {
        _phoneController.text = widget.identifier!;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();

      final metadata = {
        'name': '$firstName $lastName',
        'phone': phone,
        'role': _selectedRole,
      };

      if (_selectedRole == 'merchant') {
        metadata['shop_name'] = _shopNameController.text.trim();
        metadata['address'] = _addressController.text.trim();
        metadata['category'] = _selectedCategory;
      }

      // Step 1: Sign up in Supabase Auth with metadata
      final signUpResponse = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      if (!mounted) return;

      if (_selectedRole == 'merchant') {
        // Show the "Pending Approval" dialog immediately
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.gold,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Application Submitted',
                  style: AppTextStyles.subheading,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: const Text(
              'Your merchant application has been submitted to the admin for review. You will be notified once your shop is approved.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: SugoBayButton(
                  text: 'OK',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/login');
                  },
                ),
              ),
            ],
          ),
        );
      } else {
        // Step 2: Show confirmation popup for Customers/Riders
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.teal,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Confirm your Account',
                  style: AppTextStyles.subheading,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Text(
              'We have sent a confirmation link to $email. Please check your Gmail to verify your account before logging in.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: SugoBayButton(
                  text: 'Got it!',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/login');
                  },
                ),
              ),
            ],
          ),
        );
      }
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
                // Name fields
                Row(
                  children: [
                    Expanded(
                      child: SugoBayTextField(
                        label: 'First Name',
                        hint: 'Juan',
                        controller: _firstNameController,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SugoBayTextField(
                        label: 'Last Name',
                        hint: 'Dela Cruz',
                        controller: _lastNameController,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Email field
                SugoBayTextField(
                  label: 'Email Address',
                  hint: 'juan@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Password field
                SugoBayTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Phone field
                SugoBayTextField(
                  label: 'Phone Number',
                  hint: '09XX XXX XXXX',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone is required';
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
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.gold,
                        ),
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
            color: isSelected ? AppColors.teal.withAlpha(30) : AppColors.cardBg,
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
