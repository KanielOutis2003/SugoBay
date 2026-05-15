import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
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

    final meta = user.userMetadata;
    final name = meta?['full_name'] ?? meta?['name'] ?? '';
    if (name.isNotEmpty) {
      _nameController.text = name;
    }

    final phone = user.phone;
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text =
          phone.startsWith('+63') ? phone.substring(3) : phone;
    }

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

      await SupabaseService.users().upsert({
        'id': userId,
        'name': _nameController.text.trim(),
        'phone': _fullPhone,
        'role': _selectedRole,
        'email': SupabaseService.currentUser?.email,
      });

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
        await _showApprovalSheet();
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

  Future<void> _showApprovalSheet() async {
    final c = context.sc;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.hourglass_top_rounded,
              color: SColors.gold,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for Admin Approval',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your merchant account has been submitted. '
              'You will be notified once approved.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text('OK',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Complete Your Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
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
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: c.textTertiary),
                ),
                const SizedBox(height: 24),

                // Name
                SugoBayTextField(
                  label: 'Full Name',
                  hint: 'Enter your name',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
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
                      style: GoogleFonts.plusJakartaSans(
                        color: SColors.gold,
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
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: SColors.gold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRoleCard(
                      c: c,
                      role: 'customer',
                      label: 'Customer',
                      icon: Icons.shopping_bag_rounded,
                    ),
                    const SizedBox(width: 10),
                    _buildRoleCard(
                      c: c,
                      role: 'rider',
                      label: 'Rider',
                      icon: Icons.delivery_dining_rounded,
                    ),
                    const SizedBox(width: 10),
                    _buildRoleCard(
                      c: c,
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
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: SColors.gold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        dropdownColor: c.cardBg,
                        isExpanded: true,
                        style: GoogleFonts.plusJakartaSans(
                            color: c.textPrimary),
                        icon: Icon(Icons.arrow_drop_down,
                            color: SColors.gold),
                        items: _merchantCategories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(
                              _formatCategory(cat),
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                                () => _selectedCategory = value);
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
    required SugoColors c,
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
                ? SColors.primary.withAlpha(30)
                : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? SColors.primary : c.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? SColors.primary : c.textPrimary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color:
                      isSelected ? SColors.primary : c.textPrimary,
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
