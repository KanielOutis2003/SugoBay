import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.restaurant,
      title: 'Order Food',
      description:
          'Browse local restaurants in Ubay and order your favorite meals delivered to your door.',
      useGoldGradient: false,
    ),
    _OnboardingPageData(
      icon: Icons.shopping_bag,
      title: 'Pahapit Errands',
      description:
          'Need something from the store? Our riders will buy and deliver items for you.',
      useGoldGradient: true,
    ),
    _OnboardingPageData(
      icon: Icons.delivery_dining,
      title: 'Fast & Reliable',
      description:
          'Track your orders in real-time with our dedicated local riders.',
      useGoldGradient: false,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.plusJakartaSans(
                      color: SColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _OnboardingPageView(page: _pages[index]),
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) =>
                      _DotIndicator(isActive: index == _currentPage),
                ),
              ),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: SugoBayButton(
                text: isLastPage ? 'Get Started' : 'Next',
                onPressed: isLastPage ? _finish : _goToNextPage,
                color: isLastPage ? SColors.coral : SColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final bool useGoldGradient;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.useGoldGradient,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPageData page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    final gradient = page.useGoldGradient
        ? const LinearGradient(
            colors: [SColors.gold, Color(0xFFD4A84B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [SColors.primary, Color(0xFF1E7A6E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final glowColor = page.useGoldGradient ? SColors.gold : SColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle with gradient background
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withAlpha(77),
                  blurRadius: 40,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Icon(page.icon, size: 80, color: Colors.white),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: GoogleFonts.plusJakartaSans(
              color: c.textSecondary,
              height: 1.65,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final bool isActive;

  const _DotIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? SColors.primary : c.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
