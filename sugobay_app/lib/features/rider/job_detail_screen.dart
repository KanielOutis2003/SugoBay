import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/open_street_map.dart';
import '../../shared/widgets.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobType; // 'food' or 'pahapit'
  final String jobId;

  const JobDetailScreen({
    super.key,
    required this.jobType,
    required this.jobId,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _orderItems = [];
  Map<String, dynamic>? _merchant;
  Map<String, dynamic>? _customer;

  Map<String, dynamic>? _pahapitRequest;

  final _actualAmountController = TextEditingController();
  final _imagePicker = ImagePicker();

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _actualAmountController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.jobType == 'food') {
        await _loadFoodOrder();
      } else {
        await _loadPahapitRequest();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error loading job: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFoodOrder() async {
    final order = await SupabaseService.orders()
        .select()
        .eq('id', widget.jobId)
        .maybeSingle();
    if (order == null) return;

    final items = await SupabaseService.orderItems()
        .select('*, menu_items(name, price)')
        .eq('order_id', widget.jobId);

    final merchant = await SupabaseService.merchants()
        .select()
        .eq('id', order['merchant_id'])
        .maybeSingle();

    final customer = await SupabaseService.users()
        .select()
        .eq('id', order['customer_id'])
        .maybeSingle();

    if (mounted) {
      setState(() {
        _order = order;
        _orderItems = List<Map<String, dynamic>>.from(items);
        _merchant = merchant;
        _customer = customer;
      });
    }
  }

  Future<void> _loadPahapitRequest() async {
    final request = await SupabaseService.pahapitRequests()
        .select()
        .eq('id', widget.jobId)
        .maybeSingle();
    if (request == null) return;

    final customer = await SupabaseService.users()
        .select()
        .eq('id', request['customer_id'])
        .maybeSingle();

    if (mounted) {
      setState(() {
        _pahapitRequest = request;
        _customer = customer;
      });
    }
  }

  void _subscribeRealtime() {
    final table =
        widget.jobType == 'food' ? 'orders' : 'pahapit_requests';
    _realtimeChannel = SupabaseService.client
        .channel('job_detail_${widget.jobType}_${widget.jobId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.jobId,
          ),
          callback: (payload) => _loadData(),
        )
        .subscribe();
  }

  // Food Order Actions
  Future<void> _acceptFoodOrder() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() => _isActionLoading = true);
    try {
      await SupabaseService.orders().update({
        'rider_id': userId,
        'status': 'accepted',
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Food order accepted!');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _pickUpFoodOrder() async {
    setState(() => _isActionLoading = true);
    try {
      await SupabaseService.orders().update({
        'status': 'picked_up',
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(
            context, 'Order picked up! Heading to customer.');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markFoodDelivered() async {
    final photo = await _takePhoto('Take delivery proof photo');
    if (photo == null) return;

    setState(() => _isActionLoading = true);
    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          'delivery_proof_${widget.jobId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final photoUrl = await SupabaseService.uploadFile(
        bucket: 'delivery-photos',
        path: fileName,
        fileBytes: bytes,
      );

      await SupabaseService.orders().update({
        'status': 'delivered',
        'delivery_proof_photo_url': photoUrl,
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Order delivered successfully!');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // Pahapit Actions
  Future<void> _acceptPahapitErrand() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() => _isActionLoading = true);
    try {
      await SupabaseService.pahapitRequests().update({
        'rider_id': userId,
        'status': 'accepted',
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Errand accepted!');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _startBuying() async {
    setState(() => _isActionLoading = true);
    try {
      await SupabaseService.pahapitRequests().update({
        'status': 'buying',
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Started buying! Good luck.');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _finishBuyingAndDeliver() async {
    final amountText = _actualAmountController.text.trim();
    if (amountText.isEmpty) {
      showSugoBaySnackBar(context, 'Enter the actual amount spent',
          isError: true);
      return;
    }

    final actualAmount = double.tryParse(amountText);
    if (actualAmount == null || actualAmount <= 0) {
      showSugoBaySnackBar(context, 'Enter a valid amount',
          isError: true);
      return;
    }

    final receiptPhoto = await _takePhoto('Take receipt photo');
    if (receiptPhoto == null) return;

    setState(() => _isActionLoading = true);
    try {
      final bytes = await receiptPhoto.readAsBytes();
      final fileName =
          'receipt_${widget.jobId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final receiptUrl = await SupabaseService.uploadFile(
        bucket: 'delivery-photos',
        path: fileName,
        fileBytes: bytes,
      );

      final errandFee =
          (_pahapitRequest?['errand_fee'] ?? AppConstants.errandFee)
              .toDouble();
      final deliveryFee =
          (_pahapitRequest?['delivery_fee'] ?? 0).toDouble();
      final totalAmount = actualAmount + errandFee + deliveryFee;

      await SupabaseService.pahapitRequests().update({
        'status': 'delivering',
        'actual_amount_spent': actualAmount,
        'receipt_photo_url': receiptUrl,
        'total_amount': totalAmount,
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(
            context, 'Now delivering to customer!');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markPahapitCompleted() async {
    final photo = await _takePhoto('Take delivery proof photo');
    if (photo == null) return;

    setState(() => _isActionLoading = true);
    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          'pahapit_proof_${widget.jobId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final photoUrl = await SupabaseService.uploadFile(
        bucket: 'delivery-photos',
        path: fileName,
        fileBytes: bytes,
      );

      await SupabaseService.pahapitRequests().update({
        'status': 'completed',
        'delivery_proof_photo_url': photoUrl,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.jobId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Errand completed!');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<XFile?> _takePhoto(String title) async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Camera error: $e',
            isError: true);
      }
      return null;
    }
  }

  Future<void> _openNavigation() async {
    String? destAddress;
    dynamic destLat;
    dynamic destLng;

    if (widget.jobType == 'food') {
      destAddress = _order?['delivery_address'];
      destLat = _order?['delivery_lat'];
      destLng = _order?['delivery_lng'];
    } else {
      final status = _pahapitRequest?['status'];
      if (status == 'accepted' || status == 'buying') {
        destAddress = _pahapitRequest?['store_name'];
        destLat = _pahapitRequest?['store_lat'];
        destLng = _pahapitRequest?['store_lng'];
      } else {
        destAddress = _customer?['address'] ??
            _pahapitRequest?['delivery_address'];
        destLat = _pahapitRequest?['delivery_lat'];
        destLng = _pahapitRequest?['delivery_lng'];
      }
    }

    final destinationPoint = parseLatLng(destLat, destLng);
    if ((destAddress == null || destAddress.isEmpty) &&
        destinationPoint == null) {
      if (mounted) {
        showSugoBaySnackBar(
            context, 'No destination address available',
            isError: true);
      }
      return;
    }

    await openExternalNavigation(
      context: context,
      destinationAddress: destAddress,
      destinationPoint: destinationPoint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.cardBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.jobType == 'food'
              ? 'Food Delivery'
              : 'Pahapit Errand',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation, color: SColors.primary),
            tooltip: 'Navigate',
            onPressed: _openNavigation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: SColors.primary))
          : widget.jobType == 'food'
              ? _buildFoodOrderDetail(c)
              : _buildPahapitDetail(c),
    );
  }

  // Food Order Detail
  Widget _buildFoodOrderDetail(SugoColors c) {
    if (_order == null) {
      return const EmptyState(
          icon: Icons.error_outline, title: 'Order not found');
    }

    final status = _order!['status'] ?? 'pending';
    final riderId = _order!['rider_id'];
    final userId = SupabaseService.currentUserId;
    final isMyJob = riderId == userId;
    final total = (_order!['total_amount'] ?? 0).toDouble();
    final deliveryFee = (_order!['delivery_fee'] ?? 0).toDouble();
    final address = _order!['delivery_address'] ?? 'No address';
    final notes = _order!['notes'] ?? '';
    final merchantName = _merchant?['shop_name'] ?? 'Unknown';
    final customerName = _customer?['name'] ?? 'Customer';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SugoBayCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SColors.coral.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant,
                    color: SColors.coral, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Food Delivery',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: SColors.coral)),
                    Text(merchantName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        )),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: SColors.gold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person,
                      color: c.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Text(customerName,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: c.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      color: c.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: c.textPrimary)),
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes,
                        color: c.textTertiary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(notes,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: c.textTertiary)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order Items',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: SColors.gold)),
              const SizedBox(height: 12),
              ..._orderItems.map((item) {
                final name =
                    item['menu_items']?['name'] ?? 'Item';
                final qty = item['quantity'] ?? 1;
                final price =
                    (item['subtotal'] ?? 0).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text('${qty}x',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: SColors.primary)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(name,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: c.textPrimary))),
                      Text(
                          '\u20B1${price.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: SColors.gold)),
                    ],
                  ),
                );
              }),
              Divider(color: c.divider, height: 20),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Delivery Fee',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: c.textPrimary)),
                  Text(
                      '\u20B1${deliveryFee.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: SColors.gold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      )),
                  Text('\u20B1${total.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: SColors.gold,
                      )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayButton(
          text: 'Open Navigation',
          onPressed: _openNavigation,
          outlined: true,
          color: SColors.primary,
        ),
        const SizedBox(height: 12),

        _buildFoodActionButton(c, status, riderId, isMyJob),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFoodActionButton(
      SugoColors c, String status, String? riderId, bool isMyJob) {
    if (riderId == null &&
        (status == 'pending' || status == 'ready_for_pickup')) {
      return SugoBayButton(
        text: 'Accept Job',
        onPressed: _acceptFoodOrder,
        isLoading: _isActionLoading,
        color: SColors.primary,
      );
    }

    if (!isMyJob) {
      return SugoBayCard(
        child: Center(
          child: Text('Assigned to another rider',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textTertiary)),
        ),
      );
    }

    if (status == 'accepted' || status == 'preparing') {
      return SugoBayCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: SColors.gold),
            ),
            const SizedBox(width: 12),
            Text('Waiting for merchant to prepare...',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: SColors.gold)),
          ],
        ),
      );
    }

    if (status == 'ready_for_pickup') {
      return SugoBayButton(
        text: 'Pick Up',
        onPressed: _pickUpFoodOrder,
        isLoading: _isActionLoading,
        color: SColors.coral,
      );
    }

    if (status == 'picked_up') {
      return SugoBayButton(
        text: 'Mark Delivered',
        onPressed: _markFoodDelivered,
        isLoading: _isActionLoading,
        color: SColors.success,
      );
    }

    if (status == 'delivered') {
      return SugoBayCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                color: SColors.success),
            const SizedBox(width: 8),
            Text('Delivered',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SColors.success,
                )),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Pahapit Detail
  Widget _buildPahapitDetail(SugoColors c) {
    if (_pahapitRequest == null) {
      return const EmptyState(
          icon: Icons.error_outline, title: 'Request not found');
    }

    final status = _pahapitRequest!['status'] ?? 'pending';
    final riderId = _pahapitRequest!['rider_id'];
    final userId = SupabaseService.currentUserId;
    final isMyJob = riderId == userId;
    final storeName =
        _pahapitRequest!['store_name'] ?? 'Unknown Store';
    final storeCategory =
        _pahapitRequest!['store_category'] ?? '';
    final itemsDescription =
        _pahapitRequest!['items_description'] ?? '';
    final budgetLimit =
        (_pahapitRequest!['budget_limit'] ?? 0).toDouble();
    final specialInstructions =
        _pahapitRequest!['special_instructions'] ?? '';
    final errandFee =
        (_pahapitRequest!['errand_fee'] ?? AppConstants.errandFee)
            .toDouble();
    final deliveryFee =
        (_pahapitRequest!['delivery_fee'] ?? 0).toDouble();
    final actualAmountSpent =
        (_pahapitRequest!['actual_amount_spent'] ?? 0).toDouble();
    final totalAmount =
        (_pahapitRequest!['total_amount'] ?? 0).toDouble();
    final customerName = _customer?['name'] ?? 'Customer';
    final customerPhone = _customer?['phone'] ?? '';
    final deliveryAddress = _customer?['address'] ??
        _pahapitRequest!['delivery_address'] ??
        'No address';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SugoBayCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_bag,
                    color: SColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pahapit Errand',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: SColors.primary)),
                    Text(storeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        )),
                    if (storeCategory.isNotEmpty)
                      Text(storeCategory,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: c.textTertiary)),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: SColors.gold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person,
                      color: c.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Text(customerName,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: c.textPrimary)),
                ],
              ),
              if (customerPhone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone,
                        color: c.textTertiary, size: 20),
                    const SizedBox(width: 8),
                    Text(customerPhone,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: c.textPrimary)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      color: c.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(deliveryAddress,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: c.textPrimary)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items to Buy',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: SColors.gold)),
              const SizedBox(height: 8),
              Text(itemsDescription,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: c.textPrimary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Budget Limit',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: c.textSecondary)),
                  Text(
                      '\u20B1${budgetLimit.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: SColors.gold,
                      )),
                ],
              ),
              if (specialInstructions.isNotEmpty) ...[
                Divider(color: c.divider, height: 20),
                Text('Special Instructions',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: SColors.coral)),
                const SizedBox(height: 4),
                Text(specialInstructions,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: c.textPrimary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fee Breakdown',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: SColors.gold)),
              const SizedBox(height: 8),
              _feeRow(c, 'Errand Fee',
                  '\u20B1${errandFee.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              _feeRow(c, 'Delivery Fee',
                  '\u20B1${deliveryFee.toStringAsFixed(2)}'),
              if (actualAmountSpent > 0) ...[
                const SizedBox(height: 4),
                _feeRow(c, 'Items Cost',
                    '\u20B1${actualAmountSpent.toStringAsFixed(2)}'),
              ],
              if (totalAmount > 0) ...[
                Divider(color: c.divider, height: 16),
                _feeRow(c, 'Total',
                    '\u20B1${totalAmount.toStringAsFixed(2)}',
                    bold: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (status == 'buying' && isMyJob)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: SColors.warning.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SColors.warning),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber,
                    color: SColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If items exceed budget of \u20B1${budgetLimit.toStringAsFixed(0)}, call customer first',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: SColors.warning),
                  ),
                ),
              ],
            ),
          ),

        SugoBayButton(
          text: 'Open Navigation',
          onPressed: _openNavigation,
          outlined: true,
          color: SColors.primary,
        ),
        const SizedBox(height: 12),

        _buildPahapitActionButton(
            c, status, riderId, isMyJob),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _feeRow(SugoColors c, String label, String value,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary)
                : GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textSecondary)),
        Text(value,
            style: bold
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SColors.gold)
                : GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: SColors.gold)),
      ],
    );
  }

  Widget _buildPahapitActionButton(
      SugoColors c, String status, String? riderId, bool isMyJob) {
    if (riderId == null && status == 'pending') {
      return SugoBayButton(
        text: 'Accept Errand',
        onPressed: _acceptPahapitErrand,
        isLoading: _isActionLoading,
        color: SColors.primary,
      );
    }

    if (!isMyJob) {
      return SugoBayCard(
        child: Center(
          child: Text('Assigned to another rider',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textTertiary)),
        ),
      );
    }

    if (status == 'accepted') {
      return SugoBayButton(
        text: 'Start Buying',
        onPressed: _startBuying,
        isLoading: _isActionLoading,
        color: SColors.gold,
      );
    }

    if (status == 'buying') {
      return Column(
        children: [
          SugoBayTextField(
            label: 'Actual Amount Spent',
            hint: 'Enter total item cost',
            controller: _actualAmountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefix:
                const Icon(Icons.payments, color: SColors.gold),
          ),
          const SizedBox(height: 12),
          SugoBayButton(
            text: 'Upload Receipt & Start Delivery',
            onPressed: _finishBuyingAndDeliver,
            isLoading: _isActionLoading,
            color: SColors.coral,
          ),
        ],
      );
    }

    if (status == 'delivering') {
      return SugoBayButton(
        text: 'Mark Completed',
        onPressed: _markPahapitCompleted,
        isLoading: _isActionLoading,
        color: SColors.success,
      );
    }

    if (status == 'completed') {
      return SugoBayCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                color: SColors.success),
            const SizedBox(width: 8),
            Text('Completed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SColors.success,
                )),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
