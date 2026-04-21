import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_client.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/customer/customer_home.dart';
import '../features/customer/food/merchant_detail_screen.dart';
import '../features/customer/food/cart_screen.dart';
import '../features/customer/food/order_tracking_screen.dart';
import '../features/customer/pahapit/pahapit_form_screen.dart';
import '../features/customer/pahapit/pahapit_tracking_screen.dart';
import '../features/customer/order_history_screen.dart';
import '../features/customer/settings_screen.dart';
import '../features/merchant/merchant_home.dart';
import '../features/merchant/menu_management_screen.dart';
import '../features/merchant/order_detail_screen.dart' as merchant_order;
import '../features/rider/rider_home.dart';
import '../features/rider/job_detail_screen.dart';
import '../features/auth/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(),
      ),

      // Customer routes
      GoRoute(
          path: '/customer', builder: (_, __) => const CustomerHomeScreen()),
      GoRoute(
        path: '/merchant/:id',
        builder: (_, state) =>
            MerchantDetailScreen(merchantId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(
        path: '/order-tracking/:id',
        builder: (_, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/pahapit/new',
          builder: (_, __) => const PahapitFormScreen()),
      GoRoute(
        path: '/pahapit/track/:id',
        builder: (_, state) =>
            PahapitTrackingScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/order-history',
          builder: (_, __) => const OrderHistoryScreen()),
      GoRoute(
          path: '/settings',
          builder: (_, __) => const CustomerSettingsScreen()),

      // Merchant routes
      GoRoute(
          path: '/merchant-home',
          builder: (_, __) => const MerchantHomeScreen()),
      GoRoute(
          path: '/menu-management',
          builder: (_, __) => const MenuManagementScreen()),
      GoRoute(
        path: '/merchant-order/:id',
        builder: (_, state) => merchant_order.OrderDetailScreen(
            orderId: state.pathParameters['id']!),
      ),

      // Rider routes
      GoRoute(
          path: '/rider-home', builder: (_, __) => const RiderHomeScreen()),
      GoRoute(
        path: '/job/:type/:id',
        builder: (_, state) => JobDetailScreen(
          jobType: state.pathParameters['type']!,
          jobId: state.pathParameters['id']!,
        ),
      ),
    ],
    redirect: (context, state) async {
      final isLoggedIn = SupabaseService.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/profile-setup' ||
          state.matchedLocation == '/';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      return null;
    },
  );
});
