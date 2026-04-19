import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import 'widgets.dart';

class MapMarkerData {
  const MapMarkerData({
    required this.point,
    required this.icon,
    required this.color,
    required this.label,
  });

  final LatLng point;
  final IconData icon;
  final Color color;
  final String label;
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

  if (parsedLat == null || parsedLng == null) {
    return null;
  }

  return LatLng(parsedLat, parsedLng);
}

Future<void> openExternalNavigation({
  required BuildContext context,
  String? destinationAddress,
  LatLng? destinationPoint,
}) async {
  final encodedAddress = destinationAddress == null || destinationAddress.isEmpty
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

class OpenStreetMapCard extends StatelessWidget {
  const OpenStreetMapCard({
    super.key,
    required this.title,
    required this.markers,
    this.emptyMessage = 'Waiting for location update...',
  });

  final String title;
  final List<MapMarkerData> markers;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final center = markers.isNotEmpty
        ? markers.first.point
        : AppConstants.defaultMapCenter;

    return SugoBayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subheading),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: markers.isEmpty
                  ? Container(
                      color: AppColors.darkGrey,
                      child: Center(
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    )
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sugobay.app',
                        ),
                        MarkerLayer(
                          markers: markers
                              .map(
                                (marker) => Marker(
                                  point: marker.point,
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    marker.icon,
                                    color: marker.color,
                                    size: 40,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
            ),
          ),
          if (markers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: markers
                  .map(
                    (marker) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(marker.icon, color: marker.color, size: 16),
                        const SizedBox(width: 6),
                        Text(marker.label, style: AppTextStyles.caption),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
