import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class ComplaintScreen extends StatefulWidget {
  final String? orderId;
  final String? pahapitId;

  const ComplaintScreen({super.key, this.orderId, this.pahapitId});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _descController = TextEditingController();
  String _type = 'order_issue';
  bool _isSubmitting = false;

  static const _types = [
    ('order_issue', 'Order Issue', Icons.shopping_bag_outlined),
    ('rider_issue', 'Rider Issue', Icons.delivery_dining),
    ('merchant_issue', 'Merchant Issue', Icons.store_outlined),
    ('app_bug', 'App Bug', Icons.bug_report_outlined),
    ('other', 'Other', Icons.help_outline),
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      showSugoBaySnackBar(context, 'Please describe your issue',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.complaints().insert({
        'customer_id': SupabaseService.currentUserId,
        'type': _type,
        'description': desc,
        'order_id': widget.orderId,
        'pahapit_id': widget.pahapitId,
        'status': 'open',
      });

      if (!mounted) return;
      showSugoBaySnackBar(
          context, 'Complaint submitted. We\'ll review it shortly.');
      context.pop();
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to submit: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    'Submit a Complaint',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What\'s the issue?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Type selector
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _types.map((t) {
                        final isSelected = _type == t.$1;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _type = t.$1);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SColors.primary
                                      .withValues(alpha: 0.1)
                                  : c.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? SColors.primary
                                    : c.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t.$3,
                                    size: 18,
                                    color: isSelected
                                        ? SColors.primary
                                        : c.textTertiary),
                                const SizedBox(width: 6),
                                Text(
                                  t.$2,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isSelected
                                        ? SColors.primary
                                        : c.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Describe the problem',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descController,
                      maxLines: 5,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: c.textPrimary),
                      cursorColor: SColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Tell us what happened...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: c.textTertiary),
                        filled: true,
                        fillColor: c.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: SColors.primary, width: 1.5),
                        ),
                      ),
                    ),

                    if (widget.orderId != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: SColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Related order: #${widget.orderId!.substring(0, 8)}...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: SColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    SugoBayButton(
                      text: 'Submit Complaint',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
