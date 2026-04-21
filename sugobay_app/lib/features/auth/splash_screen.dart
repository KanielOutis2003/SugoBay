import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = SupabaseService.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      final profile = await SupabaseService.getUserProfile();
      if (!mounted) return;

      // No profile or incomplete → profile setup
      if (profile == null ||
          profile['role'] == null ||
          profile['phone'] == null) {
        context.go('/profile-setup');
        return;
      }

      _routeByRole(profile);
    } catch (e) {
      if (!mounted) return;
      context.go('/login');
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
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.primaryBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
