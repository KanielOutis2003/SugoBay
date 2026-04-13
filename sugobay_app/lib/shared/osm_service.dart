import 'dart:convert';
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
      print('Geocoding error: $e');
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
      print('OSRM distance error: $e');
    }
    return null;
  }
}
