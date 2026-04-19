import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';
import 'food/food_tab.dart';
import 'pahapit/pahapit_tab.dart';
import 'habal_habal_tab.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<FoodTabViewState> _foodTabKey = GlobalKey();
  final GlobalKey<PahapitTabViewState> _pahapitTabKey = GlobalKey();

  void _handleRefresh() {
    switch (_currentIndex) {
      case 0:
        _foodTabKey.currentState?.refresh();
        break;
      case 1:
        _pahapitTabKey.currentState?.refresh();
        break;
    }
    showSugoBaySnackBar(context, 'Refreshed');
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Logout', style: AppTextStyles.subheading),
        content: const Text('Are you sure you want to logout?',
            style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await SupabaseService.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBg,
        title: Text(
          AppConstants.appName,
          style: AppTextStyles.heading.copyWith(
            foreground: Paint()
              ..shader = AppColors.primaryGradient
                  .createShader(const Rect.fromLTWH(0, 0, 120, 30)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            tooltip: 'Refresh',
            onPressed: _handleRefresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline, color: AppColors.white),
            color: AppColors.cardBg,
            onSelected: (value) {
              switch (value) {
                case 'history':
                  context.push('/order-history');
                  break;
                case 'settings':
                  context.push('/settings');
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppColors.teal, size: 20),
                    SizedBox(width: 10),
                    Text('Order History',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: AppColors.gold, size: 20),
                    SizedBox(width: 10),
                    Text('Settings',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.coral, size: 20),
                    SizedBox(width: 10),
                    Text('Logout',
                        style: TextStyle(color: AppColors.coral)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FoodTabView(key: _foodTabKey),
          PahapitTabView(key: _pahapitTabKey),
          const HabalHabalTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Food',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Pahapit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.motorcycle),
            label: 'Habal-habal',
          ),
        ],
      ),
    );
  }
}
