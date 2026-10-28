import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import 'widgets.dart';

export 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

class MapMarkerData {
  const MapMarkerData({
    required this.point,
    required this.icon,
    required this.color,
    required this.label,
    this.size = 40,
    this.pulse = false,
  });

  final LatLng point;
  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final bool pulse;
}

LatLng? parseLatLng(dynamic lat, dynamic lng) {
  final parsedLat = switch (lat) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  final parsedLng = switch (lng) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  if (parsedLat == null || parsedLng == null) return null;
  return LatLng(parsedLat, parsedLng);
}

Future<void> openExternalNavigation({
  required BuildContext context,
  String? destinationAddress,
  LatLng? destinationPoint,
}) async {
  final encodedAddress =
      destinationAddress == null || destinationAddress.isEmpty
          ? null
          : Uri.encodeComponent(destinationAddress);

  final urls = <Uri>[
    if (destinationPoint != null)
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${destinationPoint.latitude},${destinationPoint.longitude}&travelmode=driving',
      ),
    if (destinationPoint != null)
      Uri.parse(
        'https://waze.com/ul?ll=${destinationPoint.latitude},${destinationPoint.longitude}&navigate=yes',
      ),
    if (encodedAddress != null)
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&travelmode=driving',
      ),
  ];

  for (final uri in urls) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  if (context.mounted) {
    showSugoBaySnackBar(context, 'Could not open navigation app',
        isError: true);
  }
}

/// Maps a Flutter Color to the closest Google Maps marker hue (0–360).
double _colorToHue(Color color) {
  final r = color.r, g = color.g, b = color.b;
  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
  if (max == min) return 0.0;
  double h;
  final d = max - min;
  if (max == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (max == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return (h / 6 * 360).clamp(0.0, 360.0);
}

class OpenStreetMapCard extends StatefulWidget {
  const OpenStreetMapCard({
    super.key,
    required this.title,
    required this.markers,
    this.emptyMessage = 'Waiting for location update...',
    this.polylinePoints,
    this.polylineColor,
    this.etaText,
    this.height = 260,
    this.showNavigateButton = false,
    this.onNavigatePressed,
  });

  final String title;
  final List<MapMarkerData> markers;
  final String emptyMessage;
  final List<LatLng>? polylinePoints;
  final Color? polylineColor;
  final String? etaText;
  final double height;
  final bool showNavigateButton;
  final VoidCallback? onNavigatePressed;

  @override
  State<OpenStreetMapCard> createState() => _OpenStreetMapCardState();
}

class _OpenStreetMapCardState extends State<OpenStreetMapCard> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant OpenStreetMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.markers != oldWidget.markers) {
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (_mapController == null || widget.markers.isEmpty) return;
    final allPoints = <LatLng>[
      ...widget.markers.map((m) => m.point),
      if (widget.polylinePoints != null) ...widget.polylinePoints!,
    ];
    if (allPoints.length < 2) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(allPoints.first, 15),
      );
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in allPoints) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return widget.markers.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      return Marker(
        markerId: MarkerId('marker_$i'),
        position: m.point,
        icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(m.color)),
        infoWindow: InfoWindow(title: m.label),
      );
    }).toSet();
  }

  Set<Polyline> _buildPolylines() {
    if (widget.polylinePoints == null || widget.polylinePoints!.length < 2) {
      return {};
    }
    return {
      Polyline(
        polylineId: const PolylineId('shadow'),
        points: widget.polylinePoints!,
        color: Colors.black38,
        width: 8,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.polylinePoints!,
        color: widget.polylineColor ?? SColors.primary,
        width: 5,
        patterns: [],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final center = widget.markers.isNotEmpty
        ? widget.markers.first.point
        : const LatLng(10.0581, 124.0474);

    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map, color: SColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      )),
                ],
              ),
              if (widget.showNavigateButton && widget.onNavigatePressed != null)
                Material(
                  color: SColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: widget.onNavigatePressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation,
                              color: SColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Navigate',
                            style: GoogleFonts.plusJakartaSans(
                              color: SColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ETA chip
          if (widget.etaText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: SColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    widget.etaText!,
                    style: GoogleFonts.plusJakartaSans(
                      color: SColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Map
          SizedBox(
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.markers.isEmpty
                  ? Container(
                      color: c.inputBg,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_searching,
                                color: c.textTertiary.withValues(alpha: 0.5),
                                size: 40),
                            const SizedBox(height: 8),
                            Text(
                              widget.emptyMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: c.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (defaultTargetPlatform == TargetPlatform.windows ||
                          defaultTargetPlatform == TargetPlatform.linux ||
                          defaultTargetPlatform == TargetPlatform.macOS)
                      ? Container(
                          color: context.sc.inputBg,
                          child: Center(
                            child: Icon(Icons.map_outlined,
                                color: context.sc.textTertiary, size: 40),
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: center,
                            zoom: 14,
                          ),
                          trafficEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          markers: _buildMarkers(),
                          polylines: _buildPolylines(),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              _fitBounds,
                            );
                          },
                        ),
            ),
          ),

          // Legend
          if (widget.markers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: widget.markers
                  .map((marker) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: marker.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: marker.color.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(marker.label,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: c.textTertiary)),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// Keep for any file that may still reference it
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
