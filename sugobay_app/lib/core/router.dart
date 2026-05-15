import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_client.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/auth/forgot_password_screen.dart';
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
import '../features/rider/habal_ride_detail_screen.dart';
import '../features/rider/shift_schedule_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/landing_screen.dart';
import '../features/customer/complaint_screen.dart';
import '../features/customer/habal_habal/habal_habal_booking_screen.dart';
import '../features/customer/habal_habal/habal_habal_tracking_screen.dart';

// Auth routes that don't require login
const _authRoutes = {'/', '/login', '/signup', '/otp', '/profile-setup', '/forgot-password', '/onboarding', '/landing'};

// Role-based route prefixes
const _customerRoutes = {'/customer', '/merchant/', '/cart', '/order-tracking/', '/pahapit/', '/habal-habal/', '/order-history', '/settings', '/complaint'};
const _merchantRoutes = {'/merchant-home', '/menu-management', '/merchant-order/'};
const _riderRoutes = {'/rider-home', '/job/', '/shift-schedule', '/rider-habal/'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/landing', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
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
      GoRoute(
          path: '/habal-habal/book',
          builder: (_, __) => const HabalHabalBookingScreen()),
      GoRoute(
        path: '/habal-habal/track/:id',
        builder: (_, state) =>
            HabalHabalTrackingScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/complaint',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>?;
          return ComplaintScreen(
            orderId: extra?['order_id'],
            pahapitId: extra?['pahapit_id'],
          );
        },
      ),

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
          path: '/shift-schedule',
          builder: (_, __) => const ShiftScheduleScreen()),
      GoRoute(
        path: '/rider-habal/:id',
        builder: (_, state) =>
            HabalRideDetailScreen(rideId: state.pathParameters['id']!),
      ),
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
      final path = state.matchedLocation;
      final isAuthRoute = _authRoutes.contains(path);

      // Not logged in — can only access auth routes
      if (!isLoggedIn && !isAuthRoute) return '/login';

      // Logged in — enforce role-based access
      if (isLoggedIn && !isAuthRoute) {
        final role = await SupabaseService.getUserRole();
        if (role == null) return null;

        final isAllowed = _isRouteAllowedForRole(path, role);
        if (!isAllowed) {
          switch (role) {
            case 'customer':
              return '/customer';
            case 'rider':
              return '/rider-home';
            case 'merchant':
              return '/merchant-home';
            default:
              return '/login';
          }
        }
      }

      return null;
    },
  );
});

bool _isRouteAllowedForRole(String path, String role) {
  switch (role) {
    case 'customer':
      return _customerRoutes.any((r) => path.startsWith(r));
    case 'rider':
      return _riderRoutes.any((r) => path.startsWith(r));
    case 'merchant':
      return _merchantRoutes.any((r) => path.startsWith(r));
    default:
      return false;
  }
}
