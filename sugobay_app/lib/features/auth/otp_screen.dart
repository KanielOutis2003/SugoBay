import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      showSugoBaySnackBar(context, 'Please enter the full 6-digit code',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.auth.verifyOTP(
        phone: widget.phone,
        token: otp,
        type: OtpType.sms,
      );

      if (!mounted) return;

      final userId = response.user?.id;
      if (userId == null) {
        showSugoBaySnackBar(context, 'Verification failed', isError: true);
        return;
      }

      final existing = await SupabaseService.users()
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (existing != null &&
          existing['role'] != null &&
          existing['phone'] != null) {
        final role = existing['role'] as String?;
        _routeByRole(role);
      } else {
        context.go('/profile-setup');
      }
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(
        context,
        'Verification failed: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeByRole(String? role) {
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

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;

    try {
      await SupabaseService.auth.signInWithOtp(phone: widget.phone);
      if (!mounted) return;
      showSugoBaySnackBar(context, 'OTP resent to ${widget.phone}');
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(
        context,
        'Failed to resend OTP: ${e.toString()}',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.message_rounded,
                size: 64,
                color: SColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your number',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit code sent to',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.phone,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SColors.gold,
                ),
              ),
              const SizedBox(height: 36),

              // OTP input fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                      cursorColor: SColors.primary,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: c.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: c.border,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: SColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_otp.length == 6) {
                          _verifyOtp();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 36),

              // Verify button
              SugoBayButton(
                text: 'Verify',
                onPressed: _verifyOtp,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: c.textTertiary),
                  ),
                  GestureDetector(
                    onTap: _resendSeconds == 0 ? _resendOtp : null,
                    child: Text(
                      _resendSeconds > 0
                          ? 'Resend in ${_resendSeconds}s'
                          : 'Resend OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _resendSeconds > 0
                            ? c.border
                            : SColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
