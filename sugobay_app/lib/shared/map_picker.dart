import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import 'osm_service.dart';
import 'widgets.dart';

/// A full-screen Google Maps picker that returns a LatLng + reverse-geocoded address.
class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = AppConstants.defaultMapCenter;
  String? _address;
  bool _isGeocoding = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition!;
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _selectedPosition = newPos);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPos, 16),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final address = await OSMService.reverseGeocode(point);
      if (mounted) setState(() => _address = address);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedPosition = point;
      _address = null;
    });
    _reverseGeocode(point);
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      MapPickerResult(position: _selectedPosition, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, color: c.textTertiary, size: 48),
              const SizedBox(height: 12),
              Text('Map picker available on Android only',
                  style: GoogleFonts.plusJakartaSans(color: c.textTertiary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedPosition,
                zoom: 16,
              ),
              trafficEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onTap: _onMapTap,
              onMapCreated: (controller) => _mapController = controller,
              markers: {
                Marker(
                  markerId: const MarkerId('selected'),
                  position: _selectedPosition,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRose,
                  ),
                  draggable: true,
                  onDragEnd: _onMapTap,
                ),
              },
            ),

            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg, c.bg.withValues(alpha: 0.0)],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(Icons.close,
                            color: c.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Pick Delivery Location',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // My location button
            Positioned(
              top: 64,
              right: 16,
              child: GestureDetector(
                onTap: _isLoadingLocation ? null : _getCurrentLocation,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoadingLocation
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SColors.primary,
                            ),
                          ),
                        )
                      : const Icon(Icons.my_location,
                          color: SColors.primary, size: 20),
                ),
              ),
            ),

            // Bottom card
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: SColors.coral, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _isGeocoding
                              ? Text('Finding address...',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, color: c.textTertiary))
                              : Text(
                                  _address ??
                                      'Tap on the map to select location',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14, color: c.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedPosition.latitude.toStringAsFixed(5)}, ${_selectedPosition.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary),
                    ),
                    const SizedBox(height: 16),
                    SugoBayButton(
                      text: 'Confirm Location',
                      onPressed: _confirmSelection,
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
}

class MapPickerResult {
  final LatLng position;
  final String? address;

  const MapPickerResult({required this.position, this.address});
}
