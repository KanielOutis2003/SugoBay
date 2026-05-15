import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';

class HabalHabalTrackingScreen extends StatefulWidget {
  final String rideId;

  const HabalHabalTrackingScreen({super.key, required this.rideId});

  @override
  State<HabalHabalTrackingScreen> createState() =>
      _HabalHabalTrackingScreenState();
}

class _HabalHabalTrackingScreenState extends State<HabalHabalTrackingScreen> {
  Map<String, dynamic>? _ride;
  Map<String, dynamic>? _rider;
  Map<String, dynamic>? _riderLocation;
  bool _isLoading = true;
  String? _error;
  Timer? _locationTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadRide();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadRide() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.habalHabalRides()
          .select()
          .eq('id', widget.rideId)
          .single();

      if (mounted) {
        setState(() {
          _ride = res;
          _isLoading = false;
        });
      }

      if (res['rider_id'] != null) {
        _loadRiderInfo(res['rider_id'] as String);
        _startLocationPolling(res['rider_id'] as String);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load ride: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToUpdates() {
    _channel = SupabaseService.client
        .channel('hh_ride_${widget.rideId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'habal_habal_rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.rideId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newRecord = payload.newRecord;
            setState(() => _ride = newRecord);
            if (newRecord['rider_id'] != null) {
              _loadRiderInfo(newRecord['rider_id'] as String);
              _startLocationPolling(newRecord['rider_id'] as String);
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadRiderInfo(String riderId) async {
    try {
      final res = await SupabaseService.users()
          .select('name, phone')
          .eq('id', riderId)
          .single();
      if (mounted) setState(() => _rider = res);
    } catch (_) {}
  }

  void _startLocationPolling(String riderId) {
    _locationTimer?.cancel();
    _fetchRiderLocation(riderId);
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchRiderLocation(riderId),
    );
  }

  Future<void> _fetchRiderLocation(String riderId) async {
    try {
      final res = await SupabaseService.riderLocations()
          .select()
          .eq('rider_id', riderId)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _riderLocation = res);
      }
    } catch (_) {}
  }

  Future<void> _cancelRide() async {
    final c = context.sc;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cancel Ride?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: SColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to cancel this ride?',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: c.inputBg,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: Text('Keep Ride',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: SColors.error,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: Text('Cancel Ride',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.habalHabalRides().update({
        'status': 'cancelled',
        'cancelled_by': 'customer',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.rideId);
      if (mounted) {
        setState(() => _ride?['status'] = 'cancelled');
        showSugoBaySnackBar(context, 'Ride cancelled');
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to cancel: $e',
            isError: true);
      }
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'searching':
        return Icons.search;
      case 'accepted':
        return Icons.check_circle;
      case 'arriving':
        return Icons.directions_bike;
      case 'in_transit':
        return Icons.motorcycle;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'searching':
        return SColors.gold;
      case 'accepted':
      case 'arriving':
        return SColors.primary;
      case 'in_transit':
        return SColors.gold;
      case 'completed':
        return SColors.success;
      case 'cancelled':
        return SColors.error;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'searching':
        return 'Searching for rider...';
      case 'accepted':
        return 'Rider accepted!';
      case 'arriving':
        return 'Rider is on the way';
      case 'in_transit':
        return 'Ride in progress';
      case 'completed':
        return 'Ride completed!';
      case 'cancelled':
        return 'Ride cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: SColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : _error != null
              ? _buildError(c)
              : _ride == null
                  ? Center(
                      child: Text('Ride not found',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: c.textTertiary)),
                    )
                  : _buildContent(c),
    );
  }

  Widget _buildError(SugoColors c) {
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
            child: SugoBayButton(text: 'Retry', onPressed: _loadRide),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SugoColors c) {
    final status = _ride!['status'] ?? 'searching';
    final pickupLat = (_ride!['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (_ride!['pickup_lng'] as num?)?.toDouble();
    final dropoffLat = (_ride!['dropoff_lat'] as num?)?.toDouble();
    final dropoffLng = (_ride!['dropoff_lng'] as num?)?.toDouble();
    final riderLat = (_riderLocation?['lat'] as num?)?.toDouble();
    final riderLng = (_riderLocation?['lng'] as num?)?.toDouble();

    final hasPickup = pickupLat != null && pickupLng != null;
    final hasDropoff = dropoffLat != null && dropoffLng != null;
    final hasRider = riderLat != null && riderLng != null;

    final initialCenter = hasPickup
        ? LatLng(pickupLat, pickupLng)
        : AppConstants.defaultMapCenter;

    return Stack(
      children: [
        // Full-screen map
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sugobay.app',
            ),
            MarkerLayer(
              markers: [
                if (hasPickup)
                  Marker(
                    point: LatLng(pickupLat, pickupLng),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.radio_button_checked,
                        color: SColors.primary, size: 32),
                  ),
                if (hasDropoff)
                  Marker(
                    point: LatLng(dropoffLat, dropoffLng),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_on,
                        color: SColors.coral, size: 32),
                  ),
                if (hasRider)
                  Marker(
                    point: LatLng(riderLat, riderLng),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.motorcycle,
                        color: SColors.gold, size: 32),
                  ),
              ],
            ),
          ],
        ),

        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/customer');
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.cardBg.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back, color: c.textPrimary, size: 20),
            ),
          ),
        ),

        // Bottom panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Status indicator
                    Icon(
                      _statusIcon(status),
                      color: _statusColor(status),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText(status),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rider info
                    if (_rider != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: SColors.primary,
                              child: Text(
                                (_rider!['name'] ?? 'R')[0]
                                    .toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Your Rider',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: c.textTertiary)),
                                  Text(_rider!['name'] ?? 'Rider',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary,
                                      )),
                                  if (_rider!['phone'] != null)
                                    Text(_rider!['phone'],
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: c.textTertiary)),
                                ],
                              ),
                            ),
                            Icon(Icons.motorcycle,
                                color: SColors.primary, size: 28),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Route info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        children: [
                          _routeRow(c, Icons.radio_button_checked,
                              SColors.primary, 'Pickup',
                              _ride!['pickup_address'] ?? 'N/A'),
                          Divider(color: c.divider, height: 16),
                          _routeRow(c, Icons.location_on,
                              SColors.coral, 'Drop-off',
                              _ride!['dropoff_address'] ?? 'N/A'),
                          Divider(color: c.divider, height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Distance',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: c.textTertiary)),
                              Text(
                                '${(_ride!['distance_km'] ?? 0).toDouble().toStringAsFixed(1)} km',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: c.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fare',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: c.textTertiary)),
                              Text(
                                '\u20B1${(_ride!['fare'] ?? 0).toDouble().toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: SColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel button
                    if (status == 'searching' || status == 'accepted')
                      SugoBayButton(
                        text: 'Cancel Ride',
                        color: SColors.error,
                        outlined: true,
                        onPressed: _cancelRide,
                      ),

                    // Rate button
                    if (status == 'completed') ...[
                      SugoBayButton(
                        text: 'Rate Ride',
                        color: SColors.gold,
                        onPressed: () => showSugoBaySnackBar(
                            context, 'Rating coming soon'),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Back to home
                    if (status == 'completed' ||
                        status == 'cancelled') ...[
                      const SizedBox(height: 8),
                      SugoBayButton(
                        text: 'Back to Home',
                        outlined: true,
                        onPressed: () => context.go('/customer'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeRow(SugoColors c, IconData icon, Color color, String label,
      String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: c.textTertiary)),
              Text(
                address,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
