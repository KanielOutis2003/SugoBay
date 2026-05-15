import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _checkAuthAndRoute();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndRoute() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = SupabaseService.currentUser;

    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      if (!mounted) return;
      context.go(hasSeenOnboarding ? '/landing' : '/onboarding');
      return;
    }

    try {
      final profile = await SupabaseService.getUserProfile();
      if (!mounted) return;

      if (profile == null ||
          profile['role'] == null ||
          profile['phone'] == null) {
        context.go('/profile-setup');
        return;
      }

      _routeByRole(profile);
    } catch (e) {
      if (!mounted) return;
      context.go('/landing');
    }
  }

  void _routeByRole(Map<String, dynamic> profile) {
    final role = profile['role'] as String?;
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
        context.go('/profile-setup');
    }
  }

  Future<void> _launchAdminPanel() async {
    final uri = Uri.parse(AppConstants.adminPanelUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    await SupabaseService.auth.signOut();
    if (!mounted) return;
    context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: c.bg,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.tagline,
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textTertiary,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
