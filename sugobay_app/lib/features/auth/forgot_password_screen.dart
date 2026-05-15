import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: '${AppConstants.adminPanelUrl}/reset-password',
      );

      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSugoBaySnackBar(context, e.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSugoBaySnackBar(
            context, 'Failed to send reset email: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: _emailSent ? _buildSuccessView(c) : _buildFormView(c),
        ),
      ),
    );
  }

  Widget _buildSuccessView(SugoColors c) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: SColors.primary, size: 56),
        ),
        const SizedBox(height: 28),
        Text(
          'Check Your Email',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
              color: c.textSecondary, height: 1.5, fontSize: 14),
        ),
        const SizedBox(height: 32),
        SugoBayButton(
          text: 'Back to Login',
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: Text(
            'Didn\'t receive it? Try again',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: SColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView(SugoColors c) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Reset Password',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              )),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: GoogleFonts.plusJakartaSans(
                color: c.textSecondary, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SugoBayTextField(
            label: 'Email Address',
            hint: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SugoBayButton(
            text: 'Send Reset Link',
            isLoading: _isLoading,
            onPressed: _sendResetEmail,
          ),
        ],
      ),
    );
  }
}
