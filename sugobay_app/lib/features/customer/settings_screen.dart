import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class CustomerSettingsScreen extends ConsumerStatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  ConsumerState<CustomerSettingsScreen> createState() =>
      _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState
    extends ConsumerState<CustomerSettingsScreen> {
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
    final c = context.sc;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
            Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: SColors.error,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: c.divider),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to log out?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: c.inputBg,
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: SColors.primary,
                      ),
                      child: Center(
                        child: Text(
                          'Yes, Logout',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      await SupabaseService.auth.signOut();
      if (mounted) context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: SColors.primary,
                  strokeWidth: 2.5,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (context.canPop()) context.pop();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c.inputBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.arrow_back,
                                  color: c.textPrimary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Settings',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Profile Section ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                            prefix: Padding(
                              padding:
                                  const EdgeInsets.only(left: 14, right: 8),
                              child: Text(
                                '+63',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: SColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SugoBayButton(
                            text: 'Save Changes',
                            onPressed: _updateProfile,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Appearance ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isDark
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                  color: SColors.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Dark Mode',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isDark,
                                  activeThumbColor: SColors.primary,
                                  onChanged: (_) {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(themeModeProvider.notifier)
                                        .toggle();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Account Info ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: c.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.border),
                            ),
                            child: Column(
                              children: [
                                _infoRow(
                                    c,
                                    'Email',
                                    _profile?['email'] ??
                                        SupabaseService
                                            .currentUser?.email ??
                                        'Not set'),
                                Divider(color: c.divider, height: 20),
                                _infoRow(c, 'Auth Provider',
                                    _resolveAuthProvider()),
                                Divider(color: c.divider, height: 20),
                                _infoRow(c, 'Role',
                                    _profile?['role'] ?? 'customer'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: c.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.border),
                            ),
                            child: Column(
                              children: [
                                _infoRow(c, 'App Version',
                                    AppConstants.version),
                                Divider(color: c.divider, height: 20),
                                _infoRow(c, 'Area', 'Ubay, Bohol'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Logout ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SugoBayButton(
                        text: 'Logout',
                        color: SColors.coral,
                        onPressed: _handleLogout,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  String _resolveAuthProvider() {
    final profile = _profile?['auth_provider'];
    if (profile != null && profile.toString().isNotEmpty) return profile;
    final user = SupabaseService.currentUser;
    if (user == null) return 'email';
    final provider = user.appMetadata['provider'] ??
        user.appMetadata['providers']?.first;
    if (provider != null) return provider.toString();
    return user.email != null ? 'email' : 'phone';
  }

  Widget _infoRow(SugoColors c, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: c.textSecondary,
            )),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: SColors.primary,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
