import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets.dart';
import '../../../shared/delivery_fee.dart';
import '../../../shared/osm_service.dart';
import 'package:latlong2/latlong.dart';
import 'merchant_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'cod';
  bool _isPlacingOrder = false;
  bool _isCalculatingFee = false;

  double _deliveryFee = AppConstants.baseDeliveryFee;
  double? _deliveryLat, _deliveryLng;
  double? _merchantLat, _merchantLng;
  double? _distanceKm;

  Map<String, CartItem> get _cart => CartDataHolder.cart;
  String get _merchantId => CartDataHolder.merchantId;
  String get _merchantName => CartDataHolder.merchantName;

  double get _subtotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _total => _subtotal + _deliveryFee;

  int get _itemCount =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);

  @override
  void initState() {
    super.initState();
    _fetchMerchantCoords();
  }

  Future<void> _fetchMerchantCoords() async {
    try {
      final res = await SupabaseService.merchants()
          .select('lat, lng')
          .eq('id', _merchantId)
          .single();
      if (mounted) {
        setState(() {
          _merchantLat = (res['lat'] as num).toDouble();
          _merchantLng = (res['lng'] as num).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error fetching merchant coords: $e');
    }
  }

  Future<void> _calculateFee() async {
    final address = _addressController.text.trim();
    if (address.isEmpty || _merchantLat == null || _merchantLng == null) return;

    setState(() => _isCalculatingFee = true);

    try {
      // 1. Geocode delivery address
      final deliveryCoords = await OSMService.geocode(address);
      if (deliveryCoords == null) {
        if (mounted) {
          showSugoBaySnackBar(
            context,
            'Could not find address location',
            isError: true,
          );
        }
        return;
      }

      _deliveryLat = deliveryCoords.latitude;
      _deliveryLng = deliveryCoords.longitude;

      // 2. Get OSRM distance
      final distance = await OSMService.getRouteDistance(
        LatLng(_merchantLat!, _merchantLng!),
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
              _deliveryFee = AppConstants.baseDeliveryFee; // Reset to base
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

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _incrementItem(String id) {
    setState(() {
      _cart[id]?.quantity++;
    });
  }

  void _decrementItem(String id) {
    setState(() {
      if (_cart[id] != null && _cart[id]!.quantity > 1) {
        _cart[id]!.quantity--;
      } else {
        _cart.remove(id);
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      showSugoBaySnackBar(context, 'Cart is empty', isError: true);
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      showSugoBaySnackBar(
        context,
        'Please enter a delivery address',
        isError: true,
      );
      return;
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      showSugoBaySnackBar(context, 'Please login first', isError: true);
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      // 1. Final geocode/fee calculation if coords are missing
      if (_deliveryLat == null || _deliveryLng == null) {
        final address = _addressController.text.trim();
        final deliveryCoords = await OSMService.geocode(address);
        if (deliveryCoords != null) {
          _deliveryLat = deliveryCoords.latitude;
          _deliveryLng = deliveryCoords.longitude;

          if (_merchantLat != null && _merchantLng != null) {
            final distance = await OSMService.getRouteDistance(
              LatLng(_merchantLat!, _merchantLng!),
              deliveryCoords,
            );
            if (distance != null) {
              _distanceKm = distance;
              _deliveryFee = DeliveryFeeCalculator.calculate(distance);
            }
          }
        }
      }

      final commissionAmount = _subtotal * AppConstants.commissionRate;

      // Insert order
      final orderRes = await SupabaseService.orders()
          .insert({
            'customer_id': userId,
            'merchant_id': _merchantId,
            'status': 'pending',
            'total_amount': _total,
            'delivery_fee': _deliveryFee,
            'commission_amount': commissionAmount,
            'payment_method': _paymentMethod,
            'delivery_address': _addressController.text.trim(),
            'delivery_lat': _deliveryLat,
            'delivery_lng': _deliveryLng,
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          })
          .select()
          .single();

      final orderId = orderRes['id'].toString();

      // Insert order items
      final orderItemsList = _cart.values
          .map(
            (item) => {
              'order_id': orderId,
              'menu_item_id': item.id,
              'item_name': item.name,
              'quantity': item.quantity,
              'unit_price': item.price,
              'subtotal': item.totalPrice,
            },
          )
          .toList();

      await SupabaseService.orderItems().insert(orderItemsList);

      // Clear cart and navigate
      CartDataHolder.clear();

      if (mounted) {
        context.go('/order-tracking/$orderId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        showSugoBaySnackBar(
          context,
          'Failed to place order: $e',
          isError: true,
        );
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
        title: const Text('Your Cart', style: AppTextStyles.subheading),
      ),
      body: _cart.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle: 'Add items from a merchant to get started',
            )
          : _buildCartContent(),
    );
  }

  Widget _buildCartContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Merchant name
          Text(_merchantName, style: AppTextStyles.subheading),
          const SizedBox(height: 16),

          // Cart items
          ..._cart.entries.map(
            (entry) => _buildCartItem(entry.key, entry.value),
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.darkGrey),
          const SizedBox(height: 12),

          // Delivery address
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SugoBayTextField(
                  label: 'Delivery Address',
                  hint: 'Enter your full address',
                  controller: _addressController,
                  prefix: const Icon(Icons.location_on, color: Colors.white54),
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
          const SizedBox(height: 16),

          // Notes
          SugoBayTextField(
            label: 'Notes (optional)',
            hint: 'Special instructions for the rider',
            controller: _notesController,
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Payment method
          Text(
            'Payment Method',
            style: AppTextStyles.body.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: 8),
          _buildPaymentOption('cod', 'Cash on Delivery (COD)', true),
          const SizedBox(height: 8),
          _buildPaymentOption('gcash', 'GCash (Coming soon)', false),

          const SizedBox(height: 24),
          const Divider(color: AppColors.darkGrey),
          const SizedBox(height: 12),

          // Price breakdown
          _buildPriceRow(
            'Subtotal ($_itemCount items)',
            '\u20B1${_subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Delivery Fee${_distanceKm != null ? ' (${_distanceKm!.toStringAsFixed(1)} km)' : ''}',
            '\u20B1${_deliveryFee.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Total',
            '\u20B1${_total.toStringAsFixed(2)}',
            isBold: true,
          ),

          const SizedBox(height: 24),

          // Place order button
          SugoBayButton(
            text: 'Place Order',
            isLoading: _isPlacingOrder,
            onPressed: _placeOrder,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCartItem(String id, CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkGrey.withAlpha(80)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u20B1${item.price.toStringAsFixed(2)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.teal),
                ),
              ],
            ),
          ),
          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQtyButton(Icons.remove, () => _decrementItem(id)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.quantity}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildQtyButton(Icons.add, () => _incrementItem(id)),
            ],
          ),
          const SizedBox(width: 12),
          // Item total
          Text(
            '\u20B1${item.totalPrice.toStringAsFixed(2)}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: AppColors.teal, size: 16),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, bool enabled) {
    return GestureDetector(
      onTap: enabled ? () => setState(() => _paymentMethod = value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _paymentMethod == value && enabled
                ? AppColors.teal
                : AppColors.darkGrey,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: enabled
                  ? (v) => setState(() => _paymentMethod = v!)
                  : null,
              activeColor: AppColors.teal,
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (!enabled) return Colors.white24;
                return states.contains(WidgetState.selected)
                    ? AppColors.teal
                    : Colors.white54;
              }),
            ),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: enabled ? AppColors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold ? AppTextStyles.subheading : AppTextStyles.body,
        ),
        Text(
          value,
          style: isBold
              ? AppTextStyles.subheading.copyWith(color: AppColors.teal)
              : AppTextStyles.body.copyWith(color: AppColors.white),
        ),
      ],
    );
  }
}
