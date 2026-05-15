import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';

class HabalHabalTab extends StatefulWidget {
  const HabalHabalTab({super.key});

  @override
  State<HabalHabalTab> createState() => HabalHabalTabState();
}

class HabalHabalTabState extends State<HabalHabalTab> {
  List<Map<String, dynamic>> _activeRides = [];
  List<Map<String, dynamic>> _recentRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> refresh() => _loadRides();

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final active = await SupabaseService.habalHabalRides()
          .select()
          .eq('customer_id', userId)
          .not('status', 'in', '(completed,cancelled)')
          .order('created_at', ascending: false);

      final recent = await SupabaseService.habalHabalRides()
          .select()
          .eq('customer_id', userId)
          .or('status.eq.completed,status.eq.cancelled')
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _activeRides = List<Map<String, dynamic>>.from(active);
          _recentRides = List<Map<String, dynamic>>.from(recent);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSugoBaySnackBar(context, 'Error loading rides: $e');
      }
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

  String _statusLabel(String status) {
    switch (status) {
      case 'searching':
        return 'Searching';
      case 'accepted':
        return 'Accepted';
      case 'arriving':
        return 'Arriving';
      case 'in_transit':
        return 'In Transit';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: SColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      color: SColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Book a ride CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SColors.primary, SColors.gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: SColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.motorcycle,
                        color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Habal-habal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Affordable motorcycle rides around Ubay',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/habal-habal/book');
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_location_alt,
                              color: SColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Book a Ride',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: SColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active rides
          if (_activeRides.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Active Rides',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                )),
            const SizedBox(height: 12),
            ..._activeRides
                .map((ride) => _buildRideCard(c, ride, isActive: true)),
          ],

          // Recent rides
          const SizedBox(height: 24),
          Text('Recent Rides',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 12),
          if (_recentRides.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.motorcycle,
                      size: 48,
                      color: c.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No rides yet',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: c.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Book your first habal-habal ride!',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary)),
                ],
              ),
            )
          else
            ..._recentRides
                .map((ride) => _buildRideCard(c, ride, isActive: false)),
        ],
      ),
    );
  }

  Widget _buildRideCard(SugoColors c, Map<String, dynamic> ride,
      {required bool isActive}) {
    final status = ride['status'] as String? ?? 'searching';
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final distance = (ride['distance_km'] as num?)?.toDouble() ?? 0;
    final pickup = ride['pickup_address'] as String? ?? 'Pickup';
    final dropoff = ride['dropoff_address'] as String? ?? 'Drop-off';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isActive
            ? () {
                HapticFeedback.selectionClick();
                context.push('/habal-habal/track/${ride['id']}');
              }
            : null,
        child: Container(
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
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _statusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\u20B1${fare.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: SColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.radio_button_checked,
                      color: SColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(pickup,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, color: SColors.coral, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(dropoff,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${distance.toStringAsFixed(1)} km',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary)),
                  if (isActive) ...[
                    const Spacer(),
                    Text('Tap to track',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: SColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios,
                        color: SColors.primary, size: 12),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
