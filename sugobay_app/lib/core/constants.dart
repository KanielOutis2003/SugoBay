import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class AppConstants {
  static String _env(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  // Supabase - ANON KEY ONLY in Flutter app
  static String get supabaseUrl => _env('SUPABASE_URL', 'YOUR_SUPABASE_URL');
  static String get supabaseAnonKey =>
      _env('SUPABASE_ANON_KEY', 'YOUR_SUPABASE_ANON_KEY');

  // OAuth
  static String get googleWebClientId =>
      _env('GOOGLE_WEB_CLIENT_ID', 'YOUR_GOOGLE_WEB_CLIENT_ID');
  static String get facebookAppId =>
      _env('FACEBOOK_APP_ID', 'YOUR_FACEBOOK_APP_ID');

  // OpenStreetMap default center (Ubay, Bohol)
  static const LatLng defaultMapCenter = LatLng(10.0570, 124.4703);

  // App Info
  static const String appName = 'SugoBay';
  static const String tagline = 'Sugo para sa tanan sa Ubay';
  static const String version = '3.0.0';

  // Delivery Fee
  static const double baseDeliveryFee = 30.0;
  static const double maxDeliveryRadiusKm = 15.0;
  static const double errandFee = 50.0;
  static const double commissionRate = 0.10;
  static const double errandFeeCutPercent = 0.20;
  static const double riderDeliveryFeePercent = 0.75;
  static const double incentivePerOrder = 5.0;

  // Rider GPS — 15s balances accuracy vs DB writes
  static const int gpsUpdateIntervalSeconds = 15;
  static const double gpsMinDistanceMeters = 10.0;

  // Habal-habal fare
  static const double habalBaseFare = 20.0;
  static const double habalPerKmRate = 8.0;
  static const double habalMinFare = 25.0;

  // Auto-rate
  static const int autoRateHours = 24;

  // Rider Shifts
  static const Map<String, Map<String, int>> shifts = {
    'morning': {'start': 6, 'end': 12},
    'lunch': {'start': 11, 'end': 14},
    'afternoon': {'start': 14, 'end': 18},
    'evening': {'start': 17, 'end': 21},
  };

  // Admin panel URL
  static String get adminPanelUrl =>
      _env('ADMIN_PANEL_URL', 'https://sugobay.shop');
}

class AppColors {
  static const Color primaryBg = Color(0xFF1A1C20);
  static const Color teal = Color(0xFF2A9D8F);
  static const Color coral = Color(0xFFE76F51);
  static const Color gold = Color(0xFFE9C46A);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF2D2F34);
  static const Color cardBg = Color(0xFF23252A);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [teal, coral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, accentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  static TextStyle heading = GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static TextStyle subheading = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: -0.3,
  );
  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    color: Colors.white70,
    height: 1.5,
  );
  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    color: Colors.white54,
  );
  static TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );
}
