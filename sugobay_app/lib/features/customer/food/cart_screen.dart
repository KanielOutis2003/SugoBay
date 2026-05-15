import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants.dart';
import '../../../core/cart_provider.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';
import '../../../shared/delivery_fee.dart';
import '../../../shared/osm_service.dart';
import 'package:latlong2/latlong.dart';
import 'merchant_detail_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();
  String _paymentMethod = 'cod';
  bool _isPlacingOrder = false;
  bool _isCalculatingFee = false;

  double _deliveryFee = AppConstants.baseDeliveryFee;
  double? _deliveryLat, _deliveryLng;
  double? _merchantLat, _merchantLng;
  double? _distanceKm;

  String? _appliedPromoCode;
  double _discountAmount = 0;
  bool _isApplyingPromo = false;

  Map<String, CartItem> get _cart => ref.read(cartProvider).cart;
  String get _merchantId => ref.read(cartProvider).merchantId;
  String get _merchantName => ref.read(cartProvider).merchantName;

  double get _subtotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _total => _subtotal + _deliveryFee - _discountAmount;
  int get _itemCount =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);

  @override
  void initState() {
    super.initState();
    _fetchMerchantCoords();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _promoController.dispose();
    super.dispose();
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

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isApplyingPromo = true);
    try {
      final res = await SupabaseService.client
          .from('promo_codes')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (res == null) {
        if (mounted) showSugoBaySnackBar(context, 'Invalid promo code', isError: true);
        return;
      }

      if (res['expires_at'] != null) {
        final expires = DateTime.tryParse(res['expires_at']);
        if (expires != null && expires.isBefore(DateTime.now())) {
          if (mounted) showSugoBaySnackBar(context, 'Promo code has expired', isError: true);
          return;
        }
      }

      final maxUses = res['max_uses'] as int?;
      final currentUses = (res['current_uses'] ?? 0) as int;
      if (maxUses != null && currentUses >= maxUses) {
        if (mounted) showSugoBaySnackBar(context, 'Promo code usage limit reached', isError: true);
        return;
      }

      final minOrder = (res['min_order_amount'] ?? 0).toDouble();
      if (_subtotal < minOrder) {
        if (mounted) showSugoBaySnackBar(context, 'Min order amount is \u20B1${minOrder.toStringAsFixed(0)}', isError: true);
        return;
      }

      final discountType = res['discount_type'] ?? 'fixed';
      final discountValue = (res['discount_value'] ?? 0).toDouble();
      double discount = discountType == 'percent'
          ? _subtotal * (discountValue / 100)
          : discountValue;
      if (discount > _subtotal) discount = _subtotal;

      if (mounted) {
        setState(() {
          _appliedPromoCode = code;
          _discountAmount = discount;
        });
        showSugoBaySnackBar(context, 'Promo applied! -\u20B1${discount.toStringAsFixed(2)}');
      }
    } catch (e) {
      if (mounted) showSugoBaySnackBar(context, 'Failed to apply promo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  void _removePromo() {
    setState(() {
      _appliedPromoCode = null;
      _discountAmount = 0;
      _promoController.clear();
    });
  }

  Future<void> _calculateFee() async {
    final address = _addressController.text.trim();
    if (address.isEmpty || _merchantLat == null || _merchantLng == null) return;

    setState(() => _isCalculatingFee = true);
    try {
      final deliveryCoords = await OSMService.geocode(address);
      if (deliveryCoords == null) {
        if (mounted) showSugoBaySnackBar(context, 'Could not find address location', isError: true);
        return;
      }

      _deliveryLat = deliveryCoords.latitude;
      _deliveryLng = deliveryCoords.longitude;

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
              showSugoBaySnackBar(context, 'Address is too far for delivery', isError: true);
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

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      showSugoBaySnackBar(context, 'Cart is empty', isError: true);
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      showSugoBaySnackBar(context, 'Please enter a delivery address', isError: true);
      return;
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      showSugoBaySnackBar(context, 'Please login first', isError: true);
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
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
            'promo_code': _appliedPromoCode,
            'discount_amount': _discountAmount,
          })
          .select()
          .single();

      final orderId = orderRes['id'].toString();

      final orderItemsList = _cart.values
          .map((item) => {
                'order_id': orderId,
                'menu_item_id': item.id,
                'name': item.name,
                'quantity': item.quantity,
                'unit_price': item.price,
                'subtotal': item.totalPrice,
              })
          .toList();

      await SupabaseService.orderItems().insert(orderItemsList);

      ref.read(cartProvider.notifier).clear();

      if (mounted) context.go('/order-tracking/$orderId');
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        showSugoBaySnackBar(context, 'Failed to place order: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _cart.isEmpty
            ? Column(
                children: [
                  _buildHeader(c),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Your cart is empty',
                      subtitle: 'Add items from a merchant to get started',
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildHeader(c),
                  Expanded(child: _buildCartContent(c)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(SugoColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/customer'),
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
          ),
          Text('Checkout Orders',
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCartContent(SugoColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ─── Deliver To ──────────────────────────────────
          Text('Deliver to',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(Icons.location_on, color: SColors.primary, size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter delivery address',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    ),
                    onSubmitted: (_) => _calculateFee(),
                  ),
                ),
                if (_isCalculatingFee)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: SColors.primary)),
                  )
                else
                  IconButton(
                    onPressed: _calculateFee,
                    icon: Icon(Icons.my_location, color: SColors.primary, size: 20),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Divider(color: c.divider),
          const SizedBox(height: 16),

          // ─── Order Summary ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Summary',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SColors.primary),
                  ),
                  child: Text('Add Items',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: SColors.primary)),
                ),
              ),
            ],
          ),
          Text(_merchantName,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary)),
          const SizedBox(height: 12),

          // Cart items
          ..._cart.entries.map((entry) => _buildCartItem(entry.key, entry.value, c)),

          const SizedBox(height: 16),

          // ─── Notes ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Notes for rider (optional)',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary),
                prefixIcon: Icon(Icons.note_alt_outlined, color: c.textTertiary, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Divider(color: c.divider),
          const SizedBox(height: 16),

          // ─── Payment Methods ─────────────────────────────
          _buildSectionRow(Icons.payment, 'Payment Methods', c,
              onTap: () => _showPaymentSheet(c)),

          const SizedBox(height: 12),

          // ─── Promo / Discounts ───────────────────────────
          if (_appliedPromoCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: SColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: SColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$_appliedPromoCode applied (-\u20B1${_discountAmount.toStringAsFixed(2)})',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: SColors.success, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: _removePromo,
                    child: Icon(Icons.close, color: c.textTertiary, size: 18),
                  ),
                ],
              ),
            )
          else
            _buildSectionRow(Icons.local_offer_outlined, 'Get Discounts', c,
                onTap: () => _showPromoSheet(c)),

          const SizedBox(height: 20),
          Divider(color: c.divider),
          const SizedBox(height: 16),

          // ─── Price Breakdown ─────────────────────────────
          _buildPriceRow('Subtotal ($_itemCount items)',
              '\u20B1${_subtotal.toStringAsFixed(2)}', c),
          const SizedBox(height: 8),
          _buildPriceRow(
              'Delivery Fee${_distanceKm != null ? ' (${_distanceKm!.toStringAsFixed(1)} km)' : ''}',
              '\u20B1${_deliveryFee.toStringAsFixed(2)}', c),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow('Discount', '-\u20B1${_discountAmount.toStringAsFixed(2)}', c,
                valueColor: SColors.success),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
              Text('\u20B1${_total.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: SColors.primary)),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Place Order Button ──────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isPlacingOrder ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: SColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: SColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isPlacingOrder
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Place Order - \u20B1${_total.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCartItem(String id, CartItem item, SugoColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: c.inputBg,
                        child: Icon(Icons.fastfood, color: c.textTertiary, size: 24),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: c.inputBg,
                        child: Icon(Icons.fastfood, color: c.textTertiary, size: 24),
                      ),
                    )
                  : Container(
                      color: SColors.primary.withValues(alpha: 0.08),
                      child: const Icon(Icons.fastfood, color: SColors.primary, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('\u20B1${item.price.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: SColors.primary)),
              ],
            ),
          ),
          // Quantity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.border),
            ),
            child: Text('${item.quantity}x',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
          const SizedBox(width: 8),
          // Edit button
          GestureDetector(
            onTap: () => _showEditQtySheet(id, item, c),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: SColors.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditQtySheet(String id, CartItem item, SugoColors c) {
    int qty = item.quantity;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(item.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text('\u20B1${item.price.toStringAsFixed(2)} each',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundQtyButton(Icons.remove, () {
                    if (qty > 0) setSheetState(() => qty--);
                  }, c),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('$qty',
                        style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  ),
                  _roundQtyButton(Icons.add, () => setSheetState(() => qty++), c),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (qty == 0)
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _cart.remove(id));
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          child: Text('Remove',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: SColors.error)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _cart[id]?.quantity = qty);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          child: Text('Update - \u20B1${(item.price * qty).toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentSheet(SugoColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Select Payment Method',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 20),
              _paymentOption('cod', 'Cash on Delivery', Icons.money, true, c, setSheetState),
              const SizedBox(height: 10),
              _paymentOption('gcash', 'GCash (Coming soon)', Icons.phone_android, false, c, setSheetState),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text('Confirm',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentOption(String value, String label, IconData icon, bool enabled,
      SugoColors c, StateSetter setSheetState) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: enabled
          ? () {
              setState(() => _paymentMethod = value);
              setSheetState(() {});
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected && enabled ? SColors.primary : c.border,
            width: isSelected && enabled ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? c.textPrimary : c.textTertiary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: enabled ? c.textPrimary : c.textTertiary)),
            ),
            if (isSelected && enabled)
              const Icon(Icons.check_circle, color: SColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  void _showPromoSheet(SugoColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Enter Promo Code',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                controller: _promoController,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'PROMO CODE',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: c.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isApplyingPromo
                    ? null
                    : () {
                        _applyPromoCode();
                        Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isApplyingPromo
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Apply',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionRow(IconData icon, String title, SugoColors c, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: SColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: c.textPrimary)),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: c.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, SugoColors c, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary)),
        Text(value, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? c.textPrimary)),
      ],
    );
  }

  Widget _roundQtyButton(IconData icon, VoidCallback onTap, SugoColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, color: SColors.primary, size: 20),
      ),
    );
  }
}
