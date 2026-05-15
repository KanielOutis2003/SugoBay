import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import 'widgets.dart';

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
    if (destinationPoint != null)
      Uri.parse(
        'https://www.openstreetmap.org/directions?to=${destinationPoint.latitude},${destinationPoint.longitude}',
      ),
    if (encodedAddress != null)
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&travelmode=driving',
      ),
    if (encodedAddress != null)
      Uri.parse(
        'https://www.openstreetmap.org/search?query=$encodedAddress',
      ),
  ];

  for (final uri in urls) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  if (context.mounted) {
    showSugoBaySnackBar(
      context,
      'Could not open navigation app',
      isError: true,
    );
  }
}

/// Calculates bounds that fit all points with padding.
LatLngBounds _boundsFromPoints(List<LatLng> points) {
  double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
  for (final p in points) {
    minLat = min(minLat, p.latitude);
    maxLat = max(maxLat, p.latitude);
    minLng = min(minLng, p.longitude);
    maxLng = max(maxLng, p.longitude);
  }
  final latPad = (maxLat - minLat) * 0.2 + 0.002;
  final lngPad = (maxLng - minLng) * 0.2 + 0.002;
  return LatLngBounds(
    LatLng(minLat - latPad, minLng - lngPad),
    LatLng(maxLat + latPad, maxLng + lngPad),
  );
}

class OpenStreetMapCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.sc;
    final isDark = context.isDark;

    // Collect all points for auto-fit
    final allPoints = <LatLng>[
      ...markers.map((m) => m.point),
      if (polylinePoints != null) ...polylinePoints!,
    ];

    final hasPoints = allPoints.isNotEmpty;
    final bounds = hasPoints && allPoints.length >= 2
        ? _boundsFromPoints(allPoints)
        : null;
    final center =
        hasPoints ? allPoints.first : AppConstants.defaultMapCenter;

    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map, color: SColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      )),
                ],
              ),
              if (showNavigateButton && onNavigatePressed != null)
                Material(
                  color: SColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onNavigatePressed,
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
          if (etaText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time,
                      color: SColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    etaText!,
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
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: markers.isEmpty
                  ? Container(
                      color: c.inputBg,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_searching,
                                color: c.textTertiary
                                    .withValues(alpha: 0.5),
                                size: 40),
                            const SizedBox(height: 8),
                            Text(
                              emptyMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: c.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 14,
                        initialCameraFit: bounds != null
                            ? CameraFit.bounds(
                                bounds: bounds,
                                padding: const EdgeInsets.all(24),
                              )
                            : null,
                      ),
                      children: [
                        // Theme-aware map tiles
                        TileLayer(
                          urlTemplate: isDark
                              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: isDark
                              ? const ['a', 'b', 'c', 'd']
                              : const [],
                          userAgentPackageName: 'com.sugobay.app',
                          retinaMode: isDark,
                        ),

                        // Route polyline with shadow effect
                        if (polylinePoints != null &&
                            polylinePoints!.length >= 2) ...[
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: polylinePoints!,
                                color: Colors.black38,
                                strokeWidth: 8.0,
                              ),
                            ],
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: polylinePoints!,
                                color:
                                    polylineColor ?? SColors.primary,
                                strokeWidth: 4.5,
                              ),
                            ],
                          ),
                        ],

                        // Custom styled markers
                        MarkerLayer(
                          markers: markers.map((marker) {
                            return Marker(
                              point: marker.point,
                              width: 60,
                              height: 70,
                              child: _StyledMarker(
                                icon: marker.icon,
                                color: marker.color,
                                label: marker.label,
                                pulse: marker.pulse,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
          ),

          // Legend
          if (markers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: markers
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
                                  color: marker.color
                                      .withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(marker.label,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: c.textTertiary)),
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

/// A styled map marker with icon bubble, drop shadow, and optional pulse.
class _StyledMarker extends StatelessWidget {
  const _StyledMarker({
    required this.icon,
    required this.color,
    required this.label,
    this.pulse = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: pulse ? 4 : 2,
              ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _TrianglePainter(color: color),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

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
