import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/open_street_map.dart';
import '../../../shared/osm_service.dart';
import '../../../shared/widgets.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _rider;
  Map<String, dynamic>? _riderLocation;
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel;
  RealtimeChannel? _riderLocationChannel;

  RouteResult? _routeResult;

  int _riderRating = 0;
  final TextEditingController _ratingCommentController = TextEditingController();
  bool _hasRated = false;
  bool _isSubmittingRating = false;

  static const List<String> _statusSteps = [
    'pending', 'accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'delivered',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _riderLocationChannel?.unsubscribe();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await SupabaseService.orders()
          .select().eq('id', widget.orderId).maybeSingle();

      if (res != null && res['rider_id'] != null) {
        final riderRes = await SupabaseService.users()
            .select().eq('id', res['rider_id']).maybeSingle();
        final riderLocation = await _loadRiderLocation(res['rider_id'] as String);
        _subscribeToRiderLocation(res['rider_id'] as String);
        if (mounted) {
          setState(() { _rider = riderRes; _riderLocation = riderLocation; });
          _fetchRoute();
        }
      }

      if (res != null && res['status'] == 'delivered') {
        final ratingRes = await SupabaseService.ratings()
            .select().eq('order_id', widget.orderId)
            .eq('customer_id', SupabaseService.currentUserId ?? '').maybeSingle();
        if (mounted && ratingRes != null) setState(() => _hasRated = true);
      }

      if (mounted) setState(() { _order = res; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load order: $e'; _isLoading = false; });
    }
  }

  void _subscribeToUpdates() {
    _channel = SupabaseService.client
        .channel('order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public', table: 'orders',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.orderId),
          callback: (payload) {
            if (mounted) {
              final newRecord = payload.newRecord;
              setState(() => _order = newRecord);
              if (newRecord['rider_id'] != null) {
                _loadRiderInfo(newRecord['rider_id'] as String);
                _subscribeToRiderLocation(newRecord['rider_id'] as String);
              }
            }
          },
        ).subscribe();
  }

  Future<void> _loadRiderInfo(String riderId) async {
    try {
      final res = await SupabaseService.users().select().eq('id', riderId).maybeSingle();
      final riderLocation = await _loadRiderLocation(riderId);
      if (mounted) { setState(() { _rider = res; _riderLocation = riderLocation; }); }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadRiderLocation(String riderId) async {
    try {
      return await SupabaseService.riderLocations().select().eq('rider_id', riderId).maybeSingle();
    } catch (_) { return null; }
  }

  void _subscribeToRiderLocation(String riderId) {
    _riderLocationChannel?.unsubscribe();
    _riderLocationChannel = SupabaseService.client
        .channel('order-rider-location-${widget.orderId}-$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public', table: 'rider_locations',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'rider_id', value: riderId),
          callback: (payload) {
            if (!mounted) return;
            setState(() => _riderLocation = payload.newRecord);
            _fetchRoute();
          },
        ).subscribe();
  }

  Future<void> _fetchRoute() async {
    final riderPoint = parseLatLng(_riderLocation?['lat'], _riderLocation?['lng']);
    final deliveryPoint = parseLatLng(_order?['delivery_lat'], _order?['delivery_lng']);
    if (riderPoint == null || deliveryPoint == null) return;

    final result = await OSMService.getRoute(riderPoint, deliveryPoint);
    if (mounted && result != null) setState(() => _routeResult = result);
  }

  Future<void> _submitRating() async {
    if (_riderRating == 0) {
      showSugoBaySnackBar(context, 'Please select a rating', isError: true);
      return;
    }
    setState(() => _isSubmittingRating = true);
    try {
      await SupabaseService.ratings().insert({
        'order_id': widget.orderId,
        'customer_id': SupabaseService.currentUserId,
        'rider_rating': _riderRating,
        'comment': _ratingCommentController.text.trim().isEmpty
            ? null : _ratingCommentController.text.trim(),
      });
      if (mounted) {
        setState(() { _hasRated = true; _isSubmittingRating = false; });
        showSugoBaySnackBar(context, 'Rating submitted. Thank you!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
        showSugoBaySnackBar(context, 'Failed to submit rating: $e', isError: true);
      }
    }
  }

  int get _currentStepIndex {
    final status = _order?['status'] ?? 'pending';
    final idx = _statusSteps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  String get _statusMessage {
    switch (_order?['status']) {
      case 'pending': return 'Looking for a driver...';
      case 'accepted': return 'Driver is heading to the restaurant...';
      case 'preparing': return 'Restaurant is preparing your order...';
      case 'ready_for_pickup': return 'Order is ready for pickup!';
      case 'picked_up': return 'Driver is on the way to you!';
      case 'delivered': return 'Order delivered!';
      case 'cancelled': return 'Order was cancelled';
      default: return 'Processing order...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator(color: SColors.primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: SColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SugoBayButton(text: 'Retry', onPressed: _loadOrder),
              ),
            ],
          ),
        ),
      );
    }
    if (_order == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const EmptyState(icon: Icons.receipt_long, title: 'Order not found'),
      );
    }

    final showMap = _rider != null &&
        ['accepted', 'preparing', 'ready_for_pickup', 'picked_up'].contains(_order!['status']);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          // Map area (top ~60%)
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                if (showMap)
                  _buildMap(c)
                else
                  _buildStatusView(c),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: CircleAvatar(
                    backgroundColor: c.bg.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: c.textPrimary, size: 20),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/customer'),
                    ),
                  ),
                ),
                // Refresh
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: c.bg.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: Icon(Icons.refresh, color: c.textPrimary, size: 20),
                      onPressed: _loadOrder,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom card area
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: _buildBottomContent(c),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(SugoColors c) {
    final riderPoint = parseLatLng(_riderLocation?['lat'], _riderLocation?['lng']);
    final deliveryPoint = parseLatLng(_order?['delivery_lat'], _order?['delivery_lng']);

    return OpenStreetMapCard(
      title: '',
      markers: [
        if (riderPoint != null)
          MapMarkerData(point: riderPoint, icon: Icons.delivery_dining, color: SColors.primary, label: 'Rider', pulse: true),
        if (deliveryPoint != null)
          MapMarkerData(point: deliveryPoint, icon: Icons.location_pin, color: SColors.coral, label: 'You'),
      ],
      emptyMessage: 'Waiting for rider GPS...',
      polylinePoints: _routeResult?.polylinePoints,
      polylineColor: SColors.primary,
      showNavigateButton: false,
    );
  }

  Widget _buildStatusView(SugoColors c) {
    return Container(
      color: SColors.primary.withValues(alpha: 0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_order!['status'] == 'delivered')
              Icon(Icons.check_circle, color: SColors.success, size: 80)
            else if (_order!['status'] == 'cancelled')
              Icon(Icons.cancel, color: SColors.error, size: 80)
            else
              SizedBox(
                width: 80, height: 80,
                child: CircularProgressIndicator(strokeWidth: 4, color: SColors.primary),
              ),
            const SizedBox(height: 20),
            _buildStatusStepper(c),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomContent(SugoColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status message
        Text(_statusMessage,
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 4),
        Text('Order #${widget.orderId.substring(0, 8)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary)),

        if (_routeResult != null) ...[
          const SizedBox(height: 4),
          Text('~${_routeResult!.durationMinutes.round()} min away',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: SColors.primary)),
        ],

        const SizedBox(height: 16),

        // Rider info card
        if (_rider != null) _buildRiderCard(c),

        // Delivery proof
        if (_order!['status'] == 'delivered' && _order!['delivery_proof_url'] != null) ...[
          const SizedBox(height: 16),
          _buildDeliveryProof(c),
        ],

        // Rating
        if (_order!['status'] == 'delivered') ...[
          const SizedBox(height: 16),
          _buildRatingSection(c),
        ],

        // Cancel
        if (_order!['status'] == 'pending' || _order!['status'] == 'accepted') ...[
          const SizedBox(height: 16),
          _buildCancelSection(c),
        ],

        const SizedBox(height: 16),

        // Action buttons (cancel, chat, call) matching Figma
        if (_rider != null && !['delivered', 'cancelled'].contains(_order!['status']))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_order!['status'] == 'pending' || _order!['status'] == 'accepted')
                _actionButton(Icons.close, SColors.coral, 'Cancel', () => _confirmCancelOrder(c), c),
              const SizedBox(width: 20),
              _actionButton(Icons.chat_bubble_rounded, SColors.primary, 'Chat', () {}, c),
              const SizedBox(width: 20),
              _actionButton(Icons.phone, SColors.success, 'Call', () {}, c),
            ],
          ),

        const SizedBox(height: 16),
        // Back to home
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => context.go('/customer'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Text('Back to Home',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
        ),
      ],
    );
  }

  Widget _buildRiderCard(SugoColors c) {
    final riderName = _rider?['name'] ?? 'Rider';
    final riderPhone = _rider?['phone'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: SColors.primary.withValues(alpha: 0.15),
            child: Text(riderName[0].toUpperCase(),
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: SColors.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(riderName,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(riderPhone,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: SColors.gold, size: 16),
              const SizedBox(width: 3),
              Text('4.8',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, String label, VoidCallback onTap, SugoColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatusStepper(SugoColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: List.generate(_statusSteps.length, (index) {
          final isActive = index <= _currentStepIndex;
          final isCurrent = index == _currentStepIndex;
          final label = _statusSteps[index].replaceAll('_', ' ');

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: isActive ? SColors.primary : c.inputBg,
                      shape: BoxShape.circle,
                      border: isCurrent ? Border.all(color: SColors.gold, width: 2) : null,
                    ),
                    child: isActive ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                  if (index < _statusSteps.length - 1)
                    Container(width: 2, height: 24, color: isActive ? SColors.primary : c.border),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent ? SColors.primary : isActive ? c.textPrimary : c.textTertiary,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDeliveryProof(SugoColors c) {
    final proofUrl = _order!['delivery_proof_url'].toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Proof',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(proofUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 80, color: c.inputBg,
                child: Center(child: Text('Unable to load image',
                    style: GoogleFonts.plusJakartaSans(color: c.textTertiary))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSection(SugoColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: SColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('You can cancel before the merchant starts preparing.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(SugoColors c) {
    if (_hasRated) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: SColors.success, size: 20),
            const SizedBox(width: 10),
            Text('You have rated this order',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: SColors.success, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your Rider',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _riderRating = starNum),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starNum <= _riderRating ? Icons.star : Icons.star_border,
                    color: SColors.gold, size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: c.inputBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border),
            ),
            child: TextField(
              controller: _ratingCommentController,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SugoBayButton(text: 'Submit Rating', isLoading: _isSubmittingRating, onPressed: _submitRating),
        ],
      ),
    );
  }

  Future<void> _confirmCancelOrder(SugoColors c) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SColors.error.withValues(alpha: 0.1), shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: SColors.error, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Cancel Order?',
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: SColors.error)),
            const SizedBox(height: 8),
            Text('This action cannot be undone.',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text('Keep Order',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SColors.error, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text('Cancel Order',
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
    );

    if (confirm == true) {
      try {
        await SupabaseService.orders().update({'status': 'cancelled'}).eq('id', widget.orderId);
        if (mounted) {
          showSugoBaySnackBar(context, 'Order cancelled successfully');
          setState(() => _order?['status'] = 'cancelled');
        }
      } catch (e) {
        if (mounted) showSugoBaySnackBar(context, 'Failed to cancel: $e', isError: true);
      }
    }
  }
}
