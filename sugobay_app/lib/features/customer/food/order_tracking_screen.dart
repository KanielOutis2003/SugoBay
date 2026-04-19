import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/open_street_map.dart';
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

  // Rating
  int _riderRating = 0;
  final TextEditingController _ratingCommentController =
      TextEditingController();
  bool _hasRated = false;
  bool _isSubmittingRating = false;

  static const List<String> _statusSteps = [
    'pending',
    'accepted',
    'preparing',
    'ready_for_pickup',
    'picked_up',
    'delivered',
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.orders()
          .select()
          .eq('id', widget.orderId)
          .maybeSingle();

      if (res != null && res['rider_id'] != null) {
        final riderRes = await SupabaseService.users()
            .select()
            .eq('id', res['rider_id'])
            .maybeSingle();
        final riderLocation = await _loadRiderLocation(
          res['rider_id'] as String,
        );
        _subscribeToRiderLocation(res['rider_id'] as String);
        if (mounted) {
          setState(() {
            _rider = riderRes;
            _riderLocation = riderLocation;
          });
        }
      }

      // Check if already rated
      if (res != null && res['status'] == 'delivered') {
        final ratingRes = await SupabaseService.ratings()
            .select()
            .eq('order_id', widget.orderId)
            .eq('rated_by', SupabaseService.currentUserId ?? '')
            .maybeSingle();
        if (mounted && ratingRes != null) {
          setState(() => _hasRated = true);
        }
      }

      if (mounted) {
        setState(() {
          _order = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load order: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToUpdates() {
    _channel = SupabaseService.client
        .channel('order-${widget.orderId}')
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
            if (mounted) {
              final newRecord = payload.newRecord;
              setState(() => _order = newRecord);
              // Load rider info if newly assigned
              if (newRecord['rider_id'] != null) {
                _loadRiderInfo(newRecord['rider_id'] as String);
                _subscribeToRiderLocation(newRecord['rider_id'] as String);
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadRiderInfo(String riderId) async {
    try {
      final res = await SupabaseService.users()
          .select()
          .eq('id', riderId)
          .maybeSingle();
      final riderLocation = await _loadRiderLocation(riderId);
      if (mounted) {
        setState(() {
          _rider = res;
          _riderLocation = riderLocation;
        });
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadRiderLocation(String riderId) async {
    try {
      return await SupabaseService.riderLocations()
          .select()
          .eq('rider_id', riderId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  void _subscribeToRiderLocation(String riderId) {
    _riderLocationChannel?.unsubscribe();
    _riderLocationChannel = SupabaseService.client
        .channel('order-rider-location-${widget.orderId}-$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rider_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: riderId,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() => _riderLocation = payload.newRecord);
          },
        )
        .subscribe();
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
        'rated_by': SupabaseService.currentUserId,
        'rated_user': _order?['rider_id'],
        'rating': _riderRating,
        'comment': _ratingCommentController.text.trim().isEmpty
            ? null
            : _ratingCommentController.text.trim(),
        'type': 'rider',
      });

      if (mounted) {
        setState(() {
          _hasRated = true;
          _isSubmittingRating = false;
        });
        showSugoBaySnackBar(context, 'Rating submitted. Thank you!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
        showSugoBaySnackBar(
          context,
          'Failed to submit rating: $e',
          isError: true,
        );
      }
    }
  }

  int get _currentStepIndex {
    final status = _order?['status'] ?? 'pending';
    final idx = _statusSteps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBg,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: const Text('Order Tracking', style: AppTextStyles.subheading),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loadOrder,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.coral, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.body),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SugoBayButton(text: 'Retry', onPressed: _loadOrder),
            ),
          ],
        ),
      );
    }
    if (_order == null) {
      return const EmptyState(
        icon: Icons.receipt_long,
        title: 'Order not found',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID
          SugoBayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${widget.orderId.substring(0, 8)}...',
                      style: AppTextStyles.subheading,
                    ),
                    StatusBadge(status: _order!['status'] ?? 'pending'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: \u20B1${(_order!['total_amount'] ?? 0).toDouble().toStringAsFixed(2)}',
                  style: AppTextStyles.body.copyWith(color: AppColors.teal),
                ),
                Text(
                  'Payment: ${(_order!['payment_method'] ?? 'cod').toString().toUpperCase()}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status stepper
          Text('Order Status', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          _buildStatusStepper(),

          // Rider info
          if (_rider != null) ...[
            const SizedBox(height: 20),
            _buildRiderCard(),
          ],

          // Rider map
          if (_order!['status'] == 'picked_up') ...[
            const SizedBox(height: 20),
            _buildRiderMap(),
          ],

          // Delivery proof
          if (_order!['status'] == 'delivered' &&
              _order!['delivery_proof_url'] != null) ...[
            const SizedBox(height: 20),
            _buildDeliveryProof(),
          ],

          // Rating section
          if (_order!['status'] == 'delivered') ...[
            const SizedBox(height: 20),
            _buildRatingSection(),
          ],

          const SizedBox(height: 40),

          // Back to home
          SugoBayButton(
            text: 'Back to Home',
            outlined: true,
            onPressed: () => context.go('/customer'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusStepper() {
    return Column(
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
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.teal : AppColors.darkGrey,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: AppColors.gold, width: 2)
                        : null,
                  ),
                  child: isActive
                      ? const Icon(
                          Icons.check,
                          color: AppColors.white,
                          size: 16,
                        )
                      : null,
                ),
                if (index < _statusSteps.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: isActive ? AppColors.teal : AppColors.darkGrey,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isCurrent
                      ? AppColors.gold
                      : isActive
                      ? AppColors.teal
                      : Colors.white38,
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildRiderCard() {
    final riderName = _rider?['full_name'] ?? 'Rider';
    final riderPhone = _rider?['phone'] ?? '';

    return SugoBayCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.teal,
            child: Text(
              riderName[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Rider', style: AppTextStyles.caption),
                Text(riderName, style: AppTextStyles.subheading),
                Text(riderPhone, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.delivery_dining, color: AppColors.teal, size: 28),
        ],
      ),
    );
  }

  Widget _buildRiderMap() {
    final riderPoint = parseLatLng(
      _riderLocation?['lat'],
      _riderLocation?['lng'],
    );
    final deliveryPoint = parseLatLng(
      _order?['delivery_lat'],
      _order?['delivery_lng'],
    );
    final markers = <MapMarkerData>[
      if (riderPoint != null)
        MapMarkerData(
          point: riderPoint,
          icon: Icons.delivery_dining,
          color: AppColors.teal,
          label: 'Rider',
        ),
      if (deliveryPoint != null)
        MapMarkerData(
          point: deliveryPoint,
          icon: Icons.location_pin,
          color: AppColors.coral,
          label: 'Delivery',
        ),
    ];

    return OpenStreetMapCard(
      title: 'Live Rider Map',
      markers: markers,
      emptyMessage: 'Waiting for rider GPS update...',
    );
  }

  Widget _buildDeliveryProof() {
    final proofUrl = _order!['delivery_proof_url'].toString();
    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Proof', style: AppTextStyles.subheading),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              proofUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: AppColors.darkGrey,
                child: const Center(
                  child: Text(
                    'Unable to load image',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    if (_hasRated) {
      return SugoBayCard(
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            Text('You have rated this order', style: AppTextStyles.body),
          ],
        ),
      );
    }

    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your Rider', style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          // Star rating
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
                    color: AppColors.gold,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Comment
          TextField(
            controller: _ratingCommentController,
            maxLines: 2,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)',
              hintStyle: AppTextStyles.caption,
              filled: true,
              fillColor: AppColors.darkGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SugoBayButton(
            text: 'Submit Rating',
            isLoading: _isSubmittingRating,
            onPressed: _submitRating,
          ),
        ],
      ),
    );
  }
}
