import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final _slides = const [
    _SlideData(
      emoji: '\u{1F354}\u{1F35F}\u{1F964}',
      bgGradient: [Color(0xFF8B3A0F), Color(0xFF2A1508)],
      glowColor: Color(0xFFE76F51),
      title: 'Craving something\ndelicious?',
      subtitle:
          'Order from your favorite local restaurants in Ubay. Hot meals delivered straight to your door.',
    ),
    _SlideData(
      emoji: '\u{1F6D2}\u{1F96C}\u{1F9F4}',
      bgGradient: [Color(0xFF1B5E4A), Color(0xFF0A2018)],
      glowColor: Color(0xFF2A9D8F),
      title: 'Too busy to go\nto the store?',
      subtitle:
          'Our riders will shop for groceries, medicines, or anything you need. Just list it, we deliver it.',
    ),
    _SlideData(
      emoji: '\u{1F3CD}\u{FE0F}\u{1F4A8}\u{1F5FA}\u{FE0F}',
      bgGradient: [Color(0xFF6B5A1E), Color(0xFF1A1508)],
      glowColor: Color(0xFFE9C46A),
      title: 'Need a ride\naround town?',
      subtitle:
          'Affordable habal-habal motorcycle rides. Book in seconds, track your rider live.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goToSignUp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/signup');
  }

  void _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final slide = _slides[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: slide.bgGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Hero image area (top 55%)
              Expanded(
                flex: 55,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _HeroSlide(data: _slides[i]),
                ),
              ),

              // Bottom content area
              Expanded(
                flex: 45,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                    child: Column(
                      children: [
                        // Title
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            slide.title,
                            key: ValueKey(slide.title),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Subtitle
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            slide.subtitle,
                            key: ValueKey(slide.subtitle),
                            style: GoogleFonts.plusJakartaSans(
                              color: c.textSecondary,
                              height: 1.55,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Dot indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _slides.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == i ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: _currentPage == i
                                    ? slide.glowColor
                                    : c.border,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Get Started button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                slide.glowColor,
                                slide.glowColor.withAlpha(180)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: slide.glowColor.withAlpha(60),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _goToSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Get Started',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Sign in link
                        GestureDetector(
                          onTap: _goToLogin,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: RichText(
                              text: TextSpan(
                                text: 'Already have an account? ',
                                style: GoogleFonts.plusJakartaSans(
                                  color: c.textTertiary,
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      color: slide.glowColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height:
                              MediaQuery.of(context).padding.bottom + 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  final String emoji;
  final List<Color> bgGradient;
  final Color glowColor;
  final String title;
  final String subtitle;

  const _SlideData({
    required this.emoji,
    required this.bgGradient,
    required this.glowColor,
    required this.title,
    required this.subtitle,
  });
}

class _HeroSlide extends StatelessWidget {
  final _SlideData data;

  const _HeroSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow behind food
        Positioned(
          top: MediaQuery.of(context).size.height * 0.08,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.glowColor.withAlpha(40),
                  blurRadius: 100,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),

        // Floating food emoji composition
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FloatingItem(
              emoji: data.emoji[0],
              size: 42,
              offset: const Offset(-60, 0),
              angle: -0.2,
            ),
            const SizedBox(height: 8),
            Text(
              data.emoji.characters
                  .elementAt(data.emoji.characters.length ~/ 2),
              style: const TextStyle(fontSize: 120),
            ),
            const SizedBox(height: 8),
            _FloatingItem(
              emoji: data.emoji.characters.last,
              size: 48,
              offset: const Offset(50, 0),
              angle: 0.15,
            ),
          ],
        ),

        // Sparkle effects
        Positioned(
          top: MediaQuery.of(context).size.height * 0.06,
          right: 50,
          child: Icon(
            Icons.auto_awesome,
            color: data.glowColor.withAlpha(60),
            size: 20,
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.18,
          left: 40,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withAlpha(30),
            size: 14,
          ),
        ),

        // Logo at top
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          child: Image.asset(
            'assets/images/logo.png',
            width: 80,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _FloatingItem extends StatelessWidget {
  final String emoji;
  final double size;
  final Offset offset;
  final double angle;

  const _FloatingItem({
    required this.emoji,
    required this.size,
    required this.offset,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Text(
          emoji,
          style: TextStyle(fontSize: size),
        ),
      ),
    );
  }
}
