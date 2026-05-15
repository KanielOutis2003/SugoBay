import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSMService {
  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Geocodes an address into LatLng coordinates.
  /// Returns null if not found or on error.
  static Future<LatLng?> geocode(String address) async {
    if (address.trim().isEmpty) return null;

    try {
      // Nominatim requires a User-Agent. Using the app's bundle ID as per best practices.
      final url = Uri.parse(
        '$_nominatimBaseUrl?q=${Uri.encodeComponent(address)}&format=json&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SugoBay/2.0 (com.sugobay.app)'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      // In production, use a proper logger
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  /// Calculates route distance in kilometers between two points using OSRM.
  /// Returns null on error.
  static Future<double?> getRouteDistance(LatLng start, LatLng end) async {
    try {
      // OSRM coordinates are {lon},{lat}
      final url = Uri.parse(
        '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=false',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          // OSRM returns distance in meters
          final double distanceMeters = data['routes'][0]['distance']
              .toDouble();
          return distanceMeters / 1000.0;
        }
      }
    } catch (e) {
      debugPrint('OSRM distance error: $e');
    }
    return null;
  }

  /// Reverse geocodes a LatLng into a human-readable address.
  /// Returns null if not found or on error.
  static Future<String?> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SugoBay/2.0 (com.sugobay.app)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
    return null;
  }

  /// Gets route between two points with full geometry (polyline) and ETA.
  /// Returns null on error.
  static Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final double distanceMeters = route['distance'].toDouble();
          final double durationSeconds = route['duration'].toDouble();

          // Parse GeoJSON coordinates into LatLng list
          final List<dynamic> coords =
              route['geometry']['coordinates'] as List<dynamic>;
          final polyline = coords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();

          return RouteResult(
            distanceKm: distanceMeters / 1000.0,
            durationMinutes: durationSeconds / 60.0,
            polylinePoints: polyline,
          );
        }
      }
    } catch (e) {
      debugPrint('OSRM route error: $e');
    }
    return null;
  }
}

class RouteResult {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> polylinePoints;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
  });
}
