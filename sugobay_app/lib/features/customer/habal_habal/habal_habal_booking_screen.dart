import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';
import '../../../shared/map_picker.dart';

class HabalHabalBookingScreen extends StatefulWidget {
  const HabalHabalBookingScreen({super.key});

  @override
  State<HabalHabalBookingScreen> createState() =>
      _HabalHabalBookingScreenState();
}

class _HabalHabalBookingScreenState extends State<HabalHabalBookingScreen> {
  LatLng? _pickupPosition;
  String? _pickupAddress;
  LatLng? _dropoffPosition;
  String? _dropoffAddress;

  final TextEditingController _noteController = TextEditingController();
  bool _isBooking = false;

  double? get _distanceKm {
    if (_pickupPosition == null || _dropoffPosition == null) return null;
    return const Distance().as(
      LengthUnit.Kilometer,
      _pickupPosition!,
      _dropoffPosition!,
    );
  }

  double? get _fare {
    final dist = _distanceKm;
    if (dist == null) return null;
    final calculated =
        AppConstants.habalBaseFare + dist * AppConstants.habalPerKmRate;
    return (calculated < AppConstants.habalMinFare
            ? AppConstants.habalMinFare
            : calculated)
        .roundToDouble();
  }

  bool get _canBook =>
      _pickupPosition != null && _dropoffPosition != null;

  Future<void> _pickLocation({required bool isPickup}) async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickupPosition = result.position;
        _pickupAddress = result.address;
      } else {
        _dropoffPosition = result.position;
        _dropoffAddress = result.address;
      }
    });
  }

  Future<void> _bookRide() async {
    if (!_canBook) return;
    setState(() => _isBooking = true);
    try {
      final response = await SupabaseService.habalHabalRides().insert({
        'customer_id': SupabaseService.currentUserId,
        'pickup_address': _pickupAddress ?? 'Dropped pin',
        'pickup_lat': _pickupPosition!.latitude,
        'pickup_lng': _pickupPosition!.longitude,
        'dropoff_address': _dropoffAddress ?? 'Dropped pin',
        'dropoff_lat': _dropoffPosition!.latitude,
        'dropoff_lng': _dropoffPosition!.longitude,
        'distance_km': _distanceKm,
        'fare': _fare,
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'status': 'searching',
      }).select().single();

      if (!mounted) return;
      final id = response['id'];
      context.push('/habal-habal/track/$id');
    } catch (e) {
      if (!mounted) return;
      showSugoBaySnackBar(context, 'Booking failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
                    onTap: () => Navigator.pop(context),
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
                    'Book a Ride',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pickup location card
                    _buildLocationCard(
                      c: c,
                      icon: Icons.radio_button_checked,
                      iconColor: SColors.primary,
                      label: 'Pickup',
                      address: _pickupAddress,
                      placeholder: 'Tap to set pickup location',
                      onTap: () => _pickLocation(isPickup: true),
                    ),

                    // Dotted line connector
                    Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Column(
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 3,
                            height: 3,
                            margin:
                                const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: c.textTertiary.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Drop-off location card
                    _buildLocationCard(
                      c: c,
                      icon: Icons.location_on,
                      iconColor: SColors.coral,
                      label: 'Drop-off',
                      address: _dropoffAddress,
                      placeholder: 'Tap to set drop-off location',
                      onTap: () => _pickLocation(isPickup: false),
                    ),

                    const SizedBox(height: 20),

                    // Fare estimate card
                    if (_canBook) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Distance',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: c.textSecondary)),
                                Text(
                                  '${_distanceKm!.toStringAsFixed(1)} km',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: c.divider, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Estimated Fare',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    )),
                                Text(
                                  '\u20B1${_fare!.toInt()}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: SColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Note field
                    SugoBayTextField(
                      label: 'Note (optional)',
                      hint: 'e.g. I\'m wearing a red shirt',
                      controller: _noteController,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 28),

                    // Book Ride button
                    SugoBayButton(
                      text: 'Book Ride',
                      onPressed: _canBook ? _bookRide : () {},
                      isLoading: _isBooking,
                      color: _canBook ? null : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required SugoColors c,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String? address,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary)),
                  const SizedBox(height: 4),
                  Text(
                    address ?? placeholder,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color:
                          address != null ? c.textPrimary : c.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }
}
