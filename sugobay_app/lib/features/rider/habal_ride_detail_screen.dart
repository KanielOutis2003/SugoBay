import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class HabalRideDetailScreen extends StatefulWidget {
  final String rideId;

  const HabalRideDetailScreen({super.key, required this.rideId});

  @override
  State<HabalRideDetailScreen> createState() =>
      _HabalRideDetailScreenState();
}

class _HabalRideDetailScreenState extends State<HabalRideDetailScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  Map<String, dynamic>? _ride;
  Map<String, dynamic>? _customer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final ride = await SupabaseService.habalHabalRides()
          .select()
          .eq('id', widget.rideId)
          .single();

      Map<String, dynamic>? customer;
      if (ride['customer_id'] != null) {
        customer = await SupabaseService.users()
            .select('name, phone')
            .eq('id', ride['customer_id'])
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          _ride = ride;
          _customer = customer;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.client
        .channel('hh_rider_${widget.rideId}')
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
            if (mounted) {
              setState(() {
                _ride = Map<String, dynamic>.from(payload.newRecord);
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _updateStatus(String newStatus,
      {Map<String, dynamic>? extra}) async {
    setState(() => _isActionLoading = true);
    try {
      final data = <String, dynamic>{'status': newStatus, ...?extra};
      await SupabaseService.habalHabalRides()
          .update(data)
          .eq('id', widget.rideId);

      if (mounted) {
        showSugoBaySnackBar(context, 'Status updated to $newStatus');
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

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'searching':
        return 'Searching';
      case 'accepted':
        return 'Accepted';
      case 'arriving':
        return 'Arriving to Pickup';
      case 'in_transit':
        return 'Ride In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'searching':
        return SColors.gold;
      case 'accepted':
        return SColors.primary;
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

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.cardBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Habal-habal Ride',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: SColors.gold))
          : _ride == null
              ? Center(
                  child: Text('Ride not found',
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textSecondary)))
              : _buildContent(c, isDark),
    );
  }

  Widget _buildContent(SugoColors c, bool isDark) {
    final ride = _ride!;
    final status = ride['status'] as String? ?? 'searching';
    final pickupLat = (ride['pickup_lat'] as num).toDouble();
    final pickupLng = (ride['pickup_lng'] as num).toDouble();
    final dropoffLat = (ride['dropoff_lat'] as num).toDouble();
    final dropoffLng = (ride['dropoff_lng'] as num).toDouble();
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final distance =
        (ride['distance_km'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        // Map
        SizedBox(
          height: 250,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(pickupLat, pickupLng),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains:
                    isDark ? const ['a', 'b', 'c', 'd'] : const [],
                userAgentPackageName: 'com.sugobay.app',
                retinaMode: isDark,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(pickupLat, pickupLng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.radio_button_checked,
                        color: SColors.primary, size: 32),
                  ),
                  Marker(
                    point: LatLng(dropoffLat, dropoffLng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: SColors.coral, size: 36),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Details
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Customer info
              SugoBayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: SColors.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person,
                            color: c.textTertiary, size: 20),
                        const SizedBox(width: 8),
                        Text(_customer?['name'] ?? 'Unknown',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: c.textPrimary)),
                        const Spacer(),
                        if (_customer?['phone'] != null)
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse(
                                'tel:${_customer!['phone']}')),
                            child: Row(
                              children: [
                                const Icon(Icons.phone,
                                    color: SColors.primary,
                                    size: 18),
                                const SizedBox(width: 4),
                                Text(_customer!['phone'],
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: SColors.primary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Route info
              SugoBayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked,
                            color: SColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              ride['pickup_address'] ?? 'Pickup',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: c.textPrimary)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigation,
                              color: SColors.primary, size: 20),
                          onPressed: () => _openNavigation(
                              pickupLat, pickupLng),
                          tooltip: 'Navigate to pickup',
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Column(
                        children: List.generate(
                            3,
                            (_) => Container(
                                  width: 2,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 1),
                                  color: c.border,
                                )),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: SColors.coral, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              ride['dropoff_address'] ?? 'Drop-off',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: c.textPrimary)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigation,
                              color: SColors.coral, size: 20),
                          onPressed: () => _openNavigation(
                              dropoffLat, dropoffLng),
                          tooltip: 'Navigate to drop-off',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: c.textTertiary)),
                        Text(
                            '\u20B1${fare.toStringAsFixed(0)}',
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

              if (ride['note'] != null &&
                  (ride['note'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                SugoBayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: SColors.gold)),
                      const SizedBox(height: 4),
                      Text(ride['note'],
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: c.textPrimary)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              if (_isActionLoading)
                const Center(
                    child: CircularProgressIndicator(
                        color: SColors.gold))
              else
                ..._buildActions(c, status),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(SugoColors c, String status) {
    switch (status) {
      case 'accepted':
        return [
          SugoBayButton(
            text: 'Arriving at Pickup',
            onPressed: () => _updateStatus('arriving'),
            color: SColors.primary,
          ),
          const SizedBox(height: 10),
          SugoBayButton(
            text: 'Cancel Ride',
            onPressed: () => _updateStatus('cancelled', extra: {
              'cancelled_by': 'rider',
              'cancelled_at': DateTime.now().toIso8601String(),
            }),
            color: SColors.error,
          ),
        ];
      case 'arriving':
        return [
          SugoBayButton(
            text: 'Passenger Picked Up - Start Ride',
            onPressed: () => _updateStatus('in_transit', extra: {
              'picked_up_at': DateTime.now().toIso8601String(),
            }),
            color: SColors.gold,
          ),
        ];
      case 'in_transit':
        return [
          SugoBayButton(
            text: 'Complete Ride',
            onPressed: () => _updateStatus('completed', extra: {
              'completed_at': DateTime.now().toIso8601String(),
            }),
            color: SColors.success,
          ),
        ];
      case 'completed':
        return [
          Center(
            child: Column(
              children: [
                const Icon(Icons.check_circle,
                    color: SColors.success, size: 48),
                const SizedBox(height: 8),
                Text('Ride completed!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: SColors.success,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SugoBayButton(
            text: 'Back to Home',
            onPressed: () => context.go('/rider-home'),
            color: SColors.primary,
          ),
        ];
      case 'cancelled':
        return [
          Center(
            child: Text('This ride was cancelled',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: SColors.error)),
          ),
          const SizedBox(height: 16),
          SugoBayButton(
            text: 'Back to Home',
            onPressed: () => context.go('/rider-home'),
            color: SColors.primary,
          ),
        ];
      default:
        return [];
    }
  }
}
