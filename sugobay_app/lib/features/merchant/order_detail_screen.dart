import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _customer;

  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrder();
  }

  @override
  void dispose() {
    _orderChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await SupabaseService.orders()
          .select('*, users!orders_customer_id_fkey(name, phone)')
          .eq('id', widget.orderId)
          .single();

      final items = await SupabaseService.orderItems()
          .select('*, menu_items(name, price)')
          .eq('order_id', widget.orderId);

      if (mounted) {
        setState(() {
          _order = order;
          _customer = order['users'];
          _items = List<Map<String, dynamic>>.from(items);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToOrder() {
    _orderChannel = SupabaseService.client
        .channel('order_detail_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            _loadOrder();
          },
        )
        .subscribe();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        '${newStatus}_at': DateTime.now().toUtc().toIso8601String(),
      };

      await SupabaseService.orders()
          .update(updateData)
          .eq('id', widget.orderId);

      if (mounted) {
        showSugoBaySnackBar(
          context,
          'Order updated to ${newStatus.replaceAll('_', ' ')}',
        );
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to update: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Cancel Order', style: AppTextStyles.subheading),
        content: Text(
          'Are you sure you want to cancel this order?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus('cancelled');
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '-';
    return DateFormat('MMM d, yyyy  h:mm a').format(dt.toLocal());
  }

  Widget _buildActionButtons() {
    if (_order == null) return const SizedBox.shrink();
    final status = _order!['status'] ?? '';

    return Column(
      children: [
        if (status == 'pending')
          SugoBayButton(
            text: 'Accept Order',
            onPressed: () => _updateStatus('accepted'),
            isLoading: _isUpdating,
            color: AppColors.teal,
          ),
        if (status == 'accepted')
          SugoBayButton(
            text: 'Start Preparing',
            onPressed: () => _updateStatus('preparing'),
            isLoading: _isUpdating,
            color: AppColors.gold,
          ),
        if (status == 'preparing')
          SugoBayButton(
            text: 'Ready for Pickup',
            onPressed: () => _updateStatus('ready_for_pickup'),
            isLoading: _isUpdating,
            color: AppColors.teal,
          ),
        if (status == 'pending' || status == 'accepted') ...[
          const SizedBox(height: 12),
          SugoBayButton(
            text: 'Cancel Order',
            onPressed: _cancelOrder,
            isLoading: _isUpdating,
            color: AppColors.coral,
            outlined: true,
          ),
        ],
      ],
    );
  }

  Widget _buildTimestampRow(String label, String? dateStr) {
    if (dateStr == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Text(
            _formatDateTime(dateStr),
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamps() {
    if (_order == null) return const SizedBox.shrink();

    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Timeline',
            style: AppTextStyles.subheading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildTimestampRow('Created', _order!['created_at']),
          _buildTimestampRow('Accepted', _order!['accepted_at']),
          _buildTimestampRow('Preparing', _order!['preparing_at']),
          _buildTimestampRow(
            'Ready for Pickup',
            _order!['ready_for_pickup_at'],
          ),
          _buildTimestampRow('Picked Up', _order!['picked_up_at']),
          _buildTimestampRow('Delivered', _order!['delivered_at']),
          _buildTimestampRow('Cancelled', _order!['cancelled_at']),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBg,
        appBar: AppBar(
          backgroundColor: AppColors.cardBg,
          title: Text('Order Details', style: AppTextStyles.subheading),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: AppColors.coral,
                ),
                const SizedBox(height: 16),
                Text('Failed to load order', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Order not found',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SugoBayButton(text: 'Retry', onPressed: _loadOrder),
              ],
            ),
          ),
        ),
      );
    }

    final orderId = _order!['id'] ?? '';
    final shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6)
        : orderId;
    final status = _order!['status'] ?? '';
    final total = (_order!['total'] ?? 0).toDouble();
    final deliveryAddress = _order!['delivery_address'] ?? 'No address';
    final notes = _order!['notes'] as String?;
    final customerName = _customer?['name'] ?? 'Customer';
    final customerPhone = _customer?['phone'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: Text('Order #$shortId', style: AppTextStyles.subheading),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StatusBadge(status: status)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer info
            SugoBayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer',
                    style: AppTextStyles.subheading.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 18,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        customerName,
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 18,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 8),
                      Text(customerPhone, style: AppTextStyles.body),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(deliveryAddress, style: AppTextStyles.body),
                      ),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Order items
            SugoBayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items',
                    style: AppTextStyles.subheading.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  ..._items.map((item) {
                    final itemName = item['menu_items']?['name'] ?? 'Item';
                    final qty = item['quantity'] ?? 1;
                    final price =
                        (item['price'] ?? item['menu_items']?['price'] ?? 0)
                            .toDouble();
                    final subtotal = price * qty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${qty}x',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              itemName,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '\u20B1${subtotal.toStringAsFixed(2)}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: AppColors.darkGrey, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: AppTextStyles.subheading.copyWith(fontSize: 16),
                      ),
                      Text(
                        '\u20B1${total.toStringAsFixed(2)}',
                        style: AppTextStyles.subheading.copyWith(
                          fontSize: 18,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Timestamps
            _buildTimestamps(),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
