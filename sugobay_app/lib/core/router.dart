import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'constants.dart';
import 'supabase_client.dart';
import '../shared/widgets.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/customer/customer_home.dart';
import '../features/customer/food/merchant_detail_screen.dart';
import '../features/customer/food/cart_screen.dart';
import '../features/customer/food/order_tracking_screen.dart';
import '../features/customer/pahapit/pahapit_form_screen.dart';
import '../features/customer/pahapit/pahapit_tracking_screen.dart';
import '../features/merchant/merchant_home.dart';
import '../features/merchant/menu_management_screen.dart';
import '../features/merchant/order_detail_screen.dart' as merchant_order;
import '../features/rider/rider_home.dart';
import '../features/rider/job_detail_screen.dart';
import '../features/auth/splash_screen.dart';

class MerchantPendingScreen extends StatelessWidget {
  const MerchantPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.gold,
                size: 80,
              ),
              const SizedBox(height: 32),
              Text(
                'Application Pending',
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your shop is currently under review by our admin. We will notify you once your application is approved.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SugoBayButton(
                text: 'Back to Login',
                onPressed: () async {
                  await SupabaseService.auth.signOut();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) =>
            OtpScreen(identifier: state.extra as String),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterScreen(identifier: state.extra as String?),
      ),
      GoRoute(
        path: '/merchant-pending',
        builder: (context, state) => const MerchantPendingScreen(),
      ),

      // Customer routes
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/merchant/:id',
        builder: (context, state) =>
            MerchantDetailScreen(merchantId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/order-tracking/:id',
        builder: (context, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pahapit/new',
        builder: (context, state) => const PahapitFormScreen(),
      ),
      GoRoute(
        path: '/pahapit/track/:id',
        builder: (context, state) =>
            PahapitTrackingScreen(requestId: state.pathParameters['id']!),
      ),

      // Merchant routes
      GoRoute(
        path: '/merchant-home',
        builder: (context, state) => const MerchantHomeScreen(),
      ),
      GoRoute(
        path: '/menu-management',
        builder: (context, state) => const MenuManagementScreen(),
      ),
      GoRoute(
        path: '/merchant-order/:id',
        builder: (context, state) => merchant_order.OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),

      // Rider routes
      GoRoute(
        path: '/rider-home',
        builder: (context, state) => const RiderHomeScreen(),
      ),
      GoRoute(
        path: '/job/:type/:id',
        builder: (context, state) => JobDetailScreen(
          jobType: state.pathParameters['type']!,
          jobId: state.pathParameters['id']!,
        ),
      ),
    ],
    redirect: (context, state) async {
      final isLoggedIn = SupabaseService.currentUser != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      return null;
    },
  );
});
