import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
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
            context, 'Order updated to ${newStatus.replaceAll('_', ' ')}');
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
    final c = context.sc;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Text('Cancel Order',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                )),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to cancel this order?',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SugoBayButton(
                    text: 'No',
                    onPressed: () => Navigator.pop(ctx, false),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SugoBayButton(
                    text: 'Yes, Cancel',
                    onPressed: () => Navigator.pop(ctx, true),
                    color: SColors.coral,
                  ),
                ),
              ],
            ),
            SizedBox(
                height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
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

  Widget _buildActionButtons(SugoColors c) {
    if (_order == null) return const SizedBox.shrink();
    final status = _order!['status'] ?? '';

    return Column(
      children: [
        if (status == 'pending')
          SugoBayButton(
            text: 'Accept Order',
            onPressed: () => _updateStatus('accepted'),
            isLoading: _isUpdating,
            color: SColors.primary,
          ),
        if (status == 'accepted')
          SugoBayButton(
            text: 'Start Preparing',
            onPressed: () => _updateStatus('preparing'),
            isLoading: _isUpdating,
            color: SColors.gold,
          ),
        if (status == 'preparing')
          SugoBayButton(
            text: 'Ready for Pickup',
            onPressed: () => _updateStatus('ready_for_pickup'),
            isLoading: _isUpdating,
            color: SColors.primary,
          ),
        if (status == 'pending' || status == 'accepted') ...[
          const SizedBox(height: 12),
          SugoBayButton(
            text: 'Cancel Order',
            onPressed: _cancelOrder,
            isLoading: _isUpdating,
            color: SColors.coral,
            outlined: true,
          ),
        ],
      ],
    );
  }

  Widget _buildTimestampRow(String label, String? dateStr, SugoColors c) {
    if (dateStr == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 14, color: c.textTertiary),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: c.textTertiary)),
          const Spacer(),
          Text(_formatDateTime(dateStr),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTimestamps(SugoColors c) {
    if (_order == null) return const SizedBox.shrink();

    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Timeline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 12),
          _buildTimestampRow('Created', _order!['created_at'], c),
          _buildTimestampRow('Accepted', _order!['accepted_at'], c),
          _buildTimestampRow('Preparing', _order!['preparing_at'], c),
          _buildTimestampRow(
              'Ready for Pickup', _order!['ready_for_pickup_at'], c),
          _buildTimestampRow('Picked Up', _order!['picked_up_at'], c),
          _buildTimestampRow('Delivered', _order!['delivered_at'], c),
          _buildTimestampRow('Cancelled', _order!['cancelled_at'], c),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(
            child: CircularProgressIndicator(color: SColors.primary)),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.cardBg,
          title: Text('Order Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          iconTheme: IconThemeData(color: c.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56,
                    color: SColors.coral),
                const SizedBox(height: 16),
                Text('Failed to load order',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    )),
                const SizedBox(height: 8),
                Text(_error ?? 'Order not found',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SugoBayButton(text: 'Retry', onPressed: _loadOrder),
              ],
            ),
          ),
        ),
      );
    }

    final orderId = _order!['id'] ?? '';
    final shortId =
        orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    final status = _order!['status'] ?? '';
    final total = (_order!['total_amount'] ?? 0).toDouble();
    final deliveryAddress = _order!['delivery_address'] ?? 'No address';
    final notes = _order!['notes'] as String?;
    final customerName = _customer?['name'] ?? 'Customer';
    final customerPhone = _customer?['phone'] ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.cardBg,
        title: Text('Order #$shortId',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
        iconTheme: IconThemeData(color: c.textPrimary),
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
                  Text('Customer',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      )),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: SColors.primary),
                      const SizedBox(width: 8),
                      Text(customerName,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: c.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 18, color: SColors.primary),
                      const SizedBox(width: 8),
                      Text(customerPhone,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: c.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: SColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(deliveryAddress,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: c.textSecondary)),
                      ),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes,
                            size: 18, color: SColors.gold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(notes,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: SColors.gold)),
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
                  Text('Items',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      )),
                  const SizedBox(height: 10),
                  ..._items.map((item) {
                    final itemName =
                        item['menu_items']?['name'] ?? 'Item';
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
                              color: SColors.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${qty}x',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: SColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(itemName,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: c.textPrimary)),
                          ),
                          Text(
                            '\u20B1${subtotal.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, color: SColors.gold),
                          ),
                        ],
                      ),
                    );
                  }),
                  Divider(color: c.divider, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          )),
                      Text(
                        '\u20B1${total.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: SColors.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Timestamps
            _buildTimestamps(c),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(c),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
