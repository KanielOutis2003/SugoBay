import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import 'widgets.dart';

class SavedAddressesSheet extends StatefulWidget {
  final Function(Map<String, dynamic> address) onSelect;

  const SavedAddressesSheet({super.key, required this.onSelect});

  @override
  State<SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<SavedAddressesSheet> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.client
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _addresses = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAddress() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    if (label.isEmpty || address.isEmpty) {
      showSugoBaySnackBar(context, 'Fill in both fields', isError: true);
      return;
    }
    try {
      await SupabaseService.client.from('saved_addresses').insert({
        'user_id': SupabaseService.currentUserId,
        'label': label,
        'address': address,
      });
      _labelController.clear();
      _addressController.clear();
      _loadAddresses();
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to save: $e', isError: true);
      }
    }
  }

  Future<void> _deleteAddress(String id) async {
    try {
      await SupabaseService.client
          .from('saved_addresses')
          .delete()
          .eq('id', id);
      _loadAddresses();
    } catch (_) {}
  }

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('work') || lower.contains('office')) {
      return Icons.work_rounded;
    }
    if (lower.contains('school')) return Icons.school_rounded;
    return Icons.location_on_rounded;
  }

  InputDecoration _inputDecoration(SugoColors c, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary),
      filled: true,
      fillColor: c.inputBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Saved Addresses',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 16),

          // Add new
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _labelController,
                  style: GoogleFonts.plusJakartaSans(
                      color: c.textPrimary, fontSize: 13),
                  cursorColor: SColors.primary,
                  decoration:
                      _inputDecoration(c, 'Label (Home, Work...)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _addressController,
                  style: GoogleFonts.plusJakartaSans(
                      color: c.textPrimary, fontSize: 13),
                  cursorColor: SColors.primary,
                  decoration: _inputDecoration(c, 'Full address'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addAddress,
                icon:
                    const Icon(Icons.add_circle, color: SColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Address list
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(
                    color: SColors.primary, strokeWidth: 2.5))
          else if (_addresses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No saved addresses yet',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: c.textTertiary)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final addr = _addresses[i];
                  return GestureDetector(
                    onTap: () {
                      widget.onSelect(addr);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Icon(_iconForLabel(addr['label'] ?? ''),
                              color: SColors.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addr['label'] ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  addr['address'] ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: c.textTertiary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteAddress(addr['id']),
                            child: Icon(Icons.delete_outline,
                                color: c.textTertiary
                                    .withValues(alpha: 0.5),
                                size: 18),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Show the saved addresses bottom sheet and return the selected address
Future<void> showSavedAddresses(
    BuildContext context, Function(Map<String, dynamic>) onSelect) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SavedAddressesSheet(onSelect: onSelect),
  );
}
