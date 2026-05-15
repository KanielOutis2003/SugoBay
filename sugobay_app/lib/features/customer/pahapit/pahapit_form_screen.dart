import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';
import '../../../shared/osm_service.dart';
import '../../../shared/delivery_fee.dart';

class PahapitFormScreen extends StatefulWidget {
  const PahapitFormScreen({super.key});

  @override
  State<PahapitFormScreen> createState() => _PahapitFormScreenState();
}

class _PahapitFormScreenState extends State<PahapitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _itemsDescController = TextEditingController();
  final _budgetController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _addressController = TextEditingController();

  String _storeCategory = 'grocery';
  XFile? _itemPhoto;
  Uint8List? _photoBytes;
  bool _isSubmitting = false;
  bool _isCalculatingFee = false;

  double _deliveryFee = AppConstants.baseDeliveryFee;
  double? _storeLat, _storeLng;
  double? _deliveryLat, _deliveryLng;
  double? _distanceKm;

  static const List<Map<String, String>> _categories = [
    {'value': 'pharmacy', 'label': 'Pharmacy'},
    {'value': 'grocery', 'label': 'Grocery'},
    {'value': 'sari_sari', 'label': 'Sari-Sari Store'},
    {'value': 'hardware', 'label': 'Hardware'},
    {'value': 'clothing', 'label': 'Clothing'},
    {'value': 'other', 'label': 'Other'},
  ];

  static const double _errandFee = AppConstants.errandFee;

  @override
  void dispose() {
    _storeNameController.dispose();
    _itemsDescController.dispose();
    _budgetController.dispose();
    _instructionsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _calculateFee() async {
    final storeName = _storeNameController.text.trim();
    final deliveryAddress = _addressController.text.trim();

    if (storeName.isEmpty || deliveryAddress.isEmpty) {
      showSugoBaySnackBar(
        context,
        'Enter store name and delivery address first',
        isError: true,
      );
      return;
    }

    setState(() => _isCalculatingFee = true);

    try {
      final storeCoords = await OSMService.geocode(storeName);
      if (storeCoords == null) {
        if (mounted) {
          showSugoBaySnackBar(context, 'Could not find store location',
              isError: true);
        }
        return;
      }
      _storeLat = storeCoords.latitude;
      _storeLng = storeCoords.longitude;

      final deliveryCoords = await OSMService.geocode(deliveryAddress);
      if (deliveryCoords == null) {
        if (mounted) {
          showSugoBaySnackBar(
              context, 'Could not find delivery address location',
              isError: true);
        }
        return;
      }
      _deliveryLat = deliveryCoords.latitude;
      _deliveryLng = deliveryCoords.longitude;

      final distance =
          await OSMService.getRouteDistance(storeCoords, deliveryCoords);

      if (mounted) {
        setState(() {
          if (distance != null) {
            _distanceKm = distance;
            final fee = DeliveryFeeCalculator.calculate(distance);
            if (fee < 0) {
              showSugoBaySnackBar(context, 'Address is too far for delivery',
                  isError: true);
              _deliveryFee = AppConstants.baseDeliveryFee;
            } else {
              _deliveryFee = fee;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error calculating fee: $e');
    } finally {
      if (mounted) setState(() => _isCalculatingFee = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _itemPhoto = picked;
        _photoBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      showSugoBaySnackBar(context, 'Please login first', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_storeLat == null || _deliveryLat == null) {
        final storeName = _storeNameController.text.trim();
        final deliveryAddress = _addressController.text.trim();

        final storeCoords = await OSMService.geocode(storeName);
        final deliveryCoords = await OSMService.geocode(deliveryAddress);

        if (storeCoords != null && deliveryCoords != null) {
          _storeLat = storeCoords.latitude;
          _storeLng = storeCoords.longitude;
          _deliveryLat = deliveryCoords.latitude;
          _deliveryLng = deliveryCoords.longitude;

          final distance =
              await OSMService.getRouteDistance(storeCoords, deliveryCoords);
          if (distance != null) {
            _deliveryFee = DeliveryFeeCalculator.calculate(distance);
          }
        }
      }

      String? imageUrl;

      if (_itemPhoto != null && _photoBytes != null) {
        final fileName =
            'pahapit/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await SupabaseService.uploadFile(
          bucket: 'pahapit-photos',
          path: fileName,
          fileBytes: _photoBytes!,
          contentType: 'image/jpeg',
        );
      }

      final budgetLimit =
          double.tryParse(_budgetController.text.trim()) ?? 0;

      final res = await SupabaseService.pahapitRequests()
          .insert({
            'customer_id': userId,
            'store_name': _storeNameController.text.trim(),
            'store_category': _storeCategory,
            'store_lat': _storeLat,
            'store_lng': _storeLng,
            'items_description': _itemsDescController.text.trim(),
            'budget_limit': budgetLimit,
            'special_instructions':
                _instructionsController.text.trim().isEmpty
                    ? null
                    : _instructionsController.text.trim(),
            'delivery_address': _addressController.text.trim(),
            'delivery_lat': _deliveryLat,
            'delivery_lng': _deliveryLng,
            'errand_fee': _errandFee,
            'delivery_fee': _deliveryFee,
            'status': 'pending',
            'payment_method': 'cod',
            if (imageUrl != null) 'item_photo_url': imageUrl,
          })
          .select()
          .single();

      if (mounted) {
        context.go('/pahapit/track/${res['id']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showSugoBaySnackBar(context, 'Failed to submit: $e',
            isError: true);
      }
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
                    'New Pahapit Request',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store name
                      SugoBayTextField(
                        label: 'Store Name',
                        hint: 'e.g. Mercury Drug, Gaisano',
                        controller: _storeNameController,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Store category
                      Text(
                        'Store Category',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: c.inputBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _storeCategory,
                            dropdownColor: c.cardBg,
                            isExpanded: true,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: c.textPrimary,
                            ),
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: c.textTertiary),
                            items: _categories
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value: cat['value'],
                                    child: Text(cat['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _storeCategory = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items description
                      SugoBayTextField(
                        label: 'Items Description',
                        hint: 'Describe what you need bought...',
                        controller: _itemsDescController,
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Budget limit
                      SugoBayTextField(
                        label: 'Budget Limit',
                        hint: '0.00',
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            '\u20B1',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: SColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Special instructions
                      SugoBayTextField(
                        label: 'Special Instructions (optional)',
                        hint: 'Any special requests or notes...',
                        controller: _instructionsController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Item photo
                      Text(
                        'Item Photo (optional)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: c.inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: _photoBytes != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  child: Image.memory(
                                    _photoBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: c.textTertiary,
                                        size: 32),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap to add photo',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: c.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Delivery address
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: SugoBayTextField(
                              label: 'Delivery Address',
                              hint: 'Enter your full delivery address',
                              controller: _addressController,
                              prefix: Icon(Icons.location_on,
                                  color: c.textTertiary),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: GestureDetector(
                              onTap: _isCalculatingFee
                                  ? null
                                  : _calculateFee,
                              child: Container(
                                width: 56,
                                decoration: BoxDecoration(
                                  color: c.inputBg,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(color: c.border),
                                ),
                                child: Center(
                                  child: _isCalculatingFee
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: SColors.primary,
                                          ),
                                        )
                                      : Icon(Icons.refresh,
                                          color: SColors.primary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Fee breakdown
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Fees',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _feeRow(c, 'Errand Fee',
                                '\u20B1${_errandFee.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            _feeRow(
                              c,
                              'Delivery Fee${_distanceKm != null ? ' (${_distanceKm!.toStringAsFixed(1)} km)' : ''}',
                              '\u20B1${_deliveryFee.toStringAsFixed(2)}',
                            ),
                            Divider(color: c.divider, height: 20),
                            _feeRow(
                              c,
                              'Est. Total Fees',
                              '\u20B1${(_errandFee + _deliveryFee).toStringAsFixed(2)}',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Exact amount will be determined after purchase. COD only.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: SColors.gold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      SugoBayButton(
                        text: 'Submit Request',
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(SugoColors c, String label, String value,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isBold ? c.textPrimary : c.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isBold ? SColors.primary : c.textSecondary,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
