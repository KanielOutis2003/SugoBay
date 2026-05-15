import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/open_street_map.dart';
import '../../../shared/widgets.dart';

class PahapitTrackingScreen extends StatefulWidget {
  final String requestId;

  const PahapitTrackingScreen({super.key, required this.requestId});

  @override
  State<PahapitTrackingScreen> createState() => _PahapitTrackingScreenState();
}

class _PahapitTrackingScreenState extends State<PahapitTrackingScreen> {
  Map<String, dynamic>? _request;
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
    'buying',
    'delivering',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequest();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _riderLocationChannel?.unsubscribe();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.pahapitRequests()
          .select()
          .eq('id', widget.requestId)
          .maybeSingle();

      if (res != null && res['rider_id'] != null) {
        final riderRes = await SupabaseService.users()
            .select()
            .eq('id', res['rider_id'])
            .maybeSingle();
        final riderLocation =
            await _loadRiderLocation(res['rider_id'] as String);
        _subscribeToRiderLocation(res['rider_id'] as String);
        if (mounted) {
          setState(() {
            _rider = riderRes;
            _riderLocation = riderLocation;
          });
        }
      }

      if (res != null && res['status'] == 'completed') {
        final ratingRes = await SupabaseService.ratings()
            .select()
            .eq('pahapit_id', widget.requestId)
            .eq('customer_id', SupabaseService.currentUserId ?? '')
            .maybeSingle();
        if (mounted && ratingRes != null) {
          setState(() => _hasRated = true);
        }
      }

      if (mounted) {
        setState(() {
          _request = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load request: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToUpdates() {
    _channel = SupabaseService.client
        .channel('pahapit-${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pahapit_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.requestId,
          ),
          callback: (payload) {
            if (mounted) {
              final newRecord = payload.newRecord;
              setState(() => _request = newRecord);
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
        .channel('pahapit-rider-location-${widget.requestId}-$riderId')
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
        'pahapit_id': widget.requestId,
        'customer_id': SupabaseService.currentUserId,
        'rider_rating': _riderRating,
        'comment': _ratingCommentController.text.trim().isEmpty
            ? null
            : _ratingCommentController.text.trim(),
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
        showSugoBaySnackBar(context, 'Failed to submit rating: $e',
            isError: true);
      }
    }
  }

  int get _currentStepIndex {
    final status = _request?['status'] ?? 'pending';
    final idx = _statusSteps.indexOf(status);
    return idx >= 0 ? idx : 0;
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
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/customer');
                      }
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
                    'Pahapit Tracking',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadRequest,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.inputBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.refresh,
                          color: c.textPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final c = context.sc;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: SColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: SColors.coral, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child:
                  SugoBayButton(text: 'Retry', onPressed: _loadRequest),
            ),
          ],
        ),
      );
    }
    if (_request == null) {
      return const EmptyState(
        icon: Icons.delivery_dining,
        title: 'Request not found',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request summary card
          _buildSummaryCard(),
          const SizedBox(height: 20),

          // Status stepper
          Text(
            'Request Status',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusStepper(),

          // Rider info
          if (_rider != null) ...[
            const SizedBox(height: 20),
            _buildRiderCard(),
          ],

          if (_request!['status'] == 'accepted' ||
              _request!['status'] == 'buying' ||
              _request!['status'] == 'delivering') ...[
            const SizedBox(height: 20),
            _buildRiderMap(),
          ],

          // Receipt and actual amount
          if (_request!['status'] == 'delivering' ||
              _request!['status'] == 'completed') ...[
            const SizedBox(height: 20),
            _buildReceiptSection(),
            const SizedBox(height: 16),
            _buildTotalBreakdown(),
          ],

          // Rating section
          if (_request!['status'] == 'completed') ...[
            const SizedBox(height: 20),
            _buildRatingSection(),
          ],

          const SizedBox(height: 32),

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

  Widget _buildSummaryCard() {
    final c = context.sc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _request!['store_name'] ?? 'Store',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              StatusBadge(status: _request!['status'] ?? 'pending'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _request!['items_description'] ?? '',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  size: 14, color: SColors.gold),
              const SizedBox(width: 4),
              Text(
                'Budget: \u20B1${(_request!['budget_limit'] ?? 0).toDouble().toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: SColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStepper() {
    final c = context.sc;

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
                    color: isActive ? SColors.primary : c.inputBg,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: SColors.gold, width: 2)
                        : null,
                  ),
                  child: isActive
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                      : null,
                ),
                if (index < _statusSteps.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: isActive ? SColors.primary : c.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: isCurrent
                      ? SColors.gold
                      : isActive
                          ? SColors.primary
                          : c.textTertiary,
                  fontSize: 13,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildRiderCard() {
    final c = context.sc;
    final riderName = _rider?['name'] ?? 'Rider';
    final riderPhone = _rider?['phone'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: SColors.primary,
            child: Text(
              riderName[0].toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Rider',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary)),
                Text(riderName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    )),
                Text(riderPhone,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.delivery_dining, color: SColors.primary, size: 28),
        ],
      ),
    );
  }

  Widget _buildRiderMap() {
    final riderPoint =
        parseLatLng(_riderLocation?['lat'], _riderLocation?['lng']);
    final storePoint =
        parseLatLng(_request?['store_lat'], _request?['store_lng']);
    final markers = <MapMarkerData>[
      if (riderPoint != null)
        MapMarkerData(
          point: riderPoint,
          icon: Icons.delivery_dining,
          color: SColors.primary,
          label: 'Rider',
          pulse: true,
        ),
      if (storePoint != null)
        MapMarkerData(
          point: storePoint,
          icon: Icons.store,
          color: SColors.gold,
          label: 'Store',
        ),
    ];

    return OpenStreetMapCard(
      title: 'Live Tracking',
      markers: markers,
      emptyMessage: 'Waiting for rider GPS update...',
      showNavigateButton: storePoint != null,
      onNavigatePressed: storePoint != null
          ? () => openExternalNavigation(
                context: context,
                destinationPoint: storePoint,
                destinationAddress: _request?['store_name'],
              )
          : null,
    );
  }

  Widget _buildReceiptSection() {
    final c = context.sc;
    final receiptUrl = _request!['receipt_photo_url'];
    final actualAmount =
        (_request!['actual_amount_spent'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Purchase Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 8),
          if (actualAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actual Amount Spent',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: c.textSecondary)),
                Text(
                  '\u20B1${actualAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: SColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (receiptUrl != null &&
              receiptUrl.toString().isNotEmpty) ...[
            Text('Receipt Photo',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: c.textTertiary)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                receiptUrl.toString(),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Unable to load receipt',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: c.textTertiary)),
                  ),
                ),
              ),
            ),
          ] else
            Text('No receipt uploaded yet',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: c.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildTotalBreakdown() {
    final c = context.sc;
    final actualAmount =
        (_request!['actual_amount_spent'] ?? 0).toDouble();
    final errandFee =
        (_request!['errand_fee'] ?? AppConstants.errandFee).toDouble();
    final deliveryFee =
        (_request!['delivery_fee'] ?? AppConstants.baseDeliveryFee)
            .toDouble();
    final total = actualAmount + errandFee + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Breakdown',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 10),
          _priceRow(
              c, 'Items Cost', '\u20B1${actualAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          _priceRow(
              c, 'Errand Fee', '\u20B1${errandFee.toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          _priceRow(c, 'Delivery Fee',
              '\u20B1${deliveryFee.toStringAsFixed(2)}'),
          Divider(color: c.divider, height: 16),
          _priceRow(c, 'Total', '\u20B1${total.toStringAsFixed(2)}',
              isBold: true),
        ],
      ),
    );
  }

  Widget _priceRow(SugoColors c, String label, String value,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: isBold ? c.textPrimary : c.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            )),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: isBold ? SColors.primary : c.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            )),
      ],
    );
  }

  Widget _buildRatingSection() {
    final c = context.sc;

    if (_hasRated) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: SColors.success),
            const SizedBox(width: 10),
            Text('You have rated this errand',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your Rider',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _riderRating = starNum);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starNum <= _riderRating
                        ? Icons.star
                        : Icons.star_border,
                    color: SColors.gold,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ratingCommentController,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
            cursorColor: SColors.primary,
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)',
              hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textTertiary),
              filled: true,
              fillColor: c.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: SColors.primary, width: 1.5),
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
