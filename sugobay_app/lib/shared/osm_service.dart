import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OSMService {
  static String get _apiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ─── Geocoding ──────────────────────────────────────────────────────────────

  static Future<LatLng?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}&key=$_apiKey',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  static Future<String?> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${point.latitude},${point.longitude}&key=$_apiKey',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
    return null;
  }

  // ─── Routing ────────────────────────────────────────────────────────────────

  static Future<double?> getRouteDistance(LatLng start, LatLng end) async {
    final result = await getRoute(start, end);
    return result?.distanceKm;
  }

  static Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&mode=driving&key=$_apiKey',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final double distanceMeters =
              (leg['distance']['value'] as num).toDouble();
          final double durationSeconds =
              (leg['duration']['value'] as num).toDouble();
          final String encodedPolyline =
              route['overview_polyline']['points'] as String;
          final polyline = _decodePolyline(encodedPolyline);
          return RouteResult(
            distanceKm: distanceMeters / 1000.0,
            durationMinutes: durationSeconds / 60.0,
            polylinePoints: polyline,
          );
        }
      }
    } catch (e) {
      debugPrint('Directions error: $e');
    }
    return null;
  }

  // ─── Google Polyline Decoder ─────────────────────────────────────────────

  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int result = 1, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lat += (result & 1) != 0 ? (~result >> 1) : (result >> 1);
      result = 1;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lng += (result & 1) != 0 ? (~result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
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
