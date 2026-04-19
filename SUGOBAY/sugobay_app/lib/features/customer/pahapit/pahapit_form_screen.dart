import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
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
      // 1. Geocode store
      final storeCoords = await OSMService.geocode(storeName);
      if (storeCoords == null) {
        if (mounted) {
          showSugoBaySnackBar(
            context,
            'Could not find store location',
            isError: true,
          );
        }
        return;
      }
      _storeLat = storeCoords.latitude;
      _storeLng = storeCoords.longitude;

      // 2. Geocode delivery
      final deliveryCoords = await OSMService.geocode(deliveryAddress);
      if (deliveryCoords == null) {
        if (mounted) {
          showSugoBaySnackBar(
            context,
            'Could not find delivery address location',
            isError: true,
          );
        }
        return;
      }
      _deliveryLat = deliveryCoords.latitude;
      _deliveryLng = deliveryCoords.longitude;

      // 3. Get OSRM distance
      final distance = await OSMService.getRouteDistance(
        storeCoords,
        deliveryCoords,
      );

      if (mounted) {
        setState(() {
          if (distance != null) {
            _distanceKm = distance;
            final fee = DeliveryFeeCalculator.calculate(distance);
            if (fee < 0) {
              showSugoBaySnackBar(
                context,
                'Address is too far for delivery',
                isError: true,
              );
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
      if (mounted) {
        setState(() => _isCalculatingFee = false);
      }
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
      // 1. Final geocode/fee calculation if coords are missing
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

          final distance = await OSMService.getRouteDistance(
            storeCoords,
            deliveryCoords,
          );
          if (distance != null) {
            _deliveryFee = DeliveryFeeCalculator.calculate(distance);
          }
        }
      }

      String? imageUrl;

      // Upload photo if provided
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

      final budgetLimit = double.tryParse(_budgetController.text.trim()) ?? 0;

      final res = await SupabaseService.pahapitRequests()
          .insert({
            'customer_id': userId,
            'store_name': _storeNameController.text.trim(),
            'store_category': _storeCategory,
            'store_lat': _storeLat,
            'store_lng': _storeLng,
            'items_description': _itemsDescController.text.trim(),
            'budget_limit': budgetLimit,
            'special_instructions': _instructionsController.text.trim().isEmpty
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
        showSugoBaySnackBar(context, 'Failed to submit: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBg,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: const Text(
          'New Pahapit Request',
          style: AppTextStyles.subheading,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Store category
              Text(
                'Store Category',
                style: AppTextStyles.body.copyWith(color: AppColors.gold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border.fromBorderSide(
                    BorderSide(color: AppColors.darkGrey),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _storeCategory,
                    dropdownColor: AppColors.cardBg,
                    isExpanded: true,
                    style: const TextStyle(color: AppColors.white),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['value'],
                            child: Text(c['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _storeCategory = v);
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Budget limit
              SugoBayTextField(
                label: 'Budget Limit',
                hint: '0.00',
                controller: _budgetController,
                keyboardType: TextInputType.number,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    '\u20B1',
                    style: TextStyle(color: AppColors.gold, fontSize: 16),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null)
                    return 'Invalid amount';
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
                style: AppTextStyles.body.copyWith(color: AppColors.gold),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.darkGrey,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _photoBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _photoBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: Colors.white38,
                              size: 32,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tap to add photo',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
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
                      prefix: const Icon(
                        Icons.location_on,
                        color: Colors.white54,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: _isCalculatingFee ? null : _calculateFee,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.darkGrey),
                        ),
                      ),
                      child: _isCalculatingFee
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.teal,
                              ),
                            )
                          : const Icon(Icons.refresh, color: AppColors.teal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Fee breakdown
              SugoBayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Fees',
                      style: AppTextStyles.subheading.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    _feeRow(
                      'Errand Fee',
                      '\u20B1${_errandFee.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 4),
                    _feeRow(
                      'Delivery Fee${_distanceKm != null ? ' (${_distanceKm!.toStringAsFixed(1)} km)' : ''}',
                      '\u20B1${_deliveryFee.toStringAsFixed(2)}',
                    ),
                    const Divider(color: AppColors.darkGrey, height: 16),
                    _feeRow(
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
                style: AppTextStyles.caption.copyWith(color: AppColors.gold),
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
    );
  }

  Widget _feeRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTextStyles.body.copyWith(color: AppColors.white)
              : AppTextStyles.body,
        ),
        Text(
          value,
          style: isBold
              ? AppTextStyles.body.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.bold,
                )
              : AppTextStyles.body,
        ),
      ],
    );
  }
}
