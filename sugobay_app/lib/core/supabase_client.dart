import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // Auth
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  // Tables
  static SupabaseQueryBuilder users() => client.from('users');
  static SupabaseQueryBuilder merchants() => client.from('merchants');
  static SupabaseQueryBuilder menuItems() => client.from('menu_items');
  static SupabaseQueryBuilder orders() => client.from('orders');
  static SupabaseQueryBuilder orderItems() => client.from('order_items');
  static SupabaseQueryBuilder pahapitRequests() =>
      client.from('pahapit_requests');
  static SupabaseQueryBuilder riderLocations() =>
      client.from('rider_locations');
  static SupabaseQueryBuilder riderShifts() => client.from('rider_shifts');
  static SupabaseQueryBuilder riderDailyPerformance() =>
      client.from('rider_daily_performance');
  static SupabaseQueryBuilder riderMonthlySummary() =>
      client.from('rider_monthly_summary');
  static SupabaseQueryBuilder ratings() => client.from('ratings');
  static SupabaseQueryBuilder complaints() => client.from('complaints');
  static SupabaseQueryBuilder announcements() => client.from('announcements');
  static SupabaseQueryBuilder appSettings() => client.from('app_settings');
  static SupabaseQueryBuilder incentiveFund() => client.from('incentive_fund');
  static SupabaseQueryBuilder subscriptions() => client.from('subscriptions');

  // Realtime channels
  static RealtimeChannel ordersChannel() =>
      client.channel('public:orders');
  static RealtimeChannel pahapitChannel() =>
      client.channel('public:pahapit_requests');
  static RealtimeChannel riderLocationChannel() =>
      client.channel('public:rider_locations');

  // Storage
  static SupabaseStorageClient get storage => client.storage;

  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    await storage.from(bucket).uploadBinary(
          path,
          fileBytes as dynamic,
          fileOptions: FileOptions(contentType: contentType ?? 'image/jpeg'),
        );
    return storage.from(bucket).getPublicUrl(path);
  }

  // Get user role
  static Future<String?> getUserRole() async {
    if (currentUserId == null) return null;
    final response = await users()
        .select('role')
        .eq('id', currentUserId!)
        .maybeSingle();
    
    if (response == null) {
      // Profile doesn't exist yet, let's create it from auth metadata
      final userMetadata = currentUser?.userMetadata;
      if (userMetadata != null) {
        final role = userMetadata['role'] as String? ?? 'customer';
        final name = userMetadata['name'] as String?;
        final phone = userMetadata['phone'] as String?;
        
        await users().insert({
          'id': currentUserId!,
          'name': name,
          'phone': phone,
          'role': role,
        });

        // If merchant, check for merchant metadata
        if (role == 'merchant') {
          final shopName = userMetadata['shop_name'] as String?;
          final address = userMetadata['address'] as String?;
          final category = userMetadata['category'] as String?;
          
          if (shopName != null) {
            await merchants().insert({
              'user_id': currentUserId!,
              'shop_name': shopName,
              'address': address,
              'category': category ?? 'restaurant',
              'lat': 0.0,
              'lng': 0.0,
              'is_approved': false,
            });
          }
        }
        return role;
      }
    }
    
    return response?['role'] as String?;
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUserId == null) return null;
    return await users().select().eq('id', currentUserId!).maybeSingle();
  }
}
