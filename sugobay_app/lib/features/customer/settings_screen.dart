import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
          _nameController.text = profile['name'] ?? '';
          final phone = profile['phone'] ?? '';
          _phoneController.text =
              phone.startsWith('+63') ? phone.substring(3) : phone;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final phone = _phoneController.text.trim();
      final cleaned = phone.startsWith('0') ? phone.substring(1) : phone;

      await SupabaseService.users().update({
        'name': _nameController.text.trim(),
        'phone': '+63$cleaned',
      }).eq('id', userId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Profile updated!');
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Update failed: $e', isError: true);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Logout', style: AppTextStyles.subheading),
        content: const Text('Are you sure?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await SupabaseService.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        title: const Text('Settings', style: AppTextStyles.subheading),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile section
                  Text('Profile',
                      style:
                          AppTextStyles.subheading.copyWith(color: AppColors.gold)),
                  const SizedBox(height: 16),
                  SugoBayTextField(
                    label: 'Full Name',
                    hint: 'Your name',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 12),
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
                  ),
                  const SizedBox(height: 16),
                  SugoBayButton(
                    text: 'Save Changes',
                    onPressed: _updateProfile,
                  ),
                  const SizedBox(height: 32),

                  // Account info
                  Text('Account',
                      style:
                          AppTextStyles.subheading.copyWith(color: AppColors.gold)),
                  const SizedBox(height: 16),
                  SugoBayCard(
                    child: Column(
                      children: [
                        _infoRow('Email',
                            _profile?['email'] ?? 'Not set'),
                        const Divider(color: AppColors.darkGrey, height: 20),
                        _infoRow('Auth Provider',
                            _profile?['auth_provider'] ?? 'Unknown'),
                        const Divider(color: AppColors.darkGrey, height: 20),
                        _infoRow('Role', _profile?['role'] ?? 'customer'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App info
                  SugoBayCard(
                    child: Column(
                      children: [
                        _infoRow('App Version', AppConstants.version),
                        const Divider(color: AppColors.darkGrey, height: 20),
                        _infoRow('Area', 'Ubay, Bohol'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SugoBayButton(
                    text: 'Logout',
                    color: AppColors.coral,
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Text(value,
            style: AppTextStyles.body
                .copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
