import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';
import 'food/food_tab.dart';
import 'pahapit/pahapit_tab.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;
  bool _profileLoading = true;
  final GlobalKey<FoodTabViewState> _foodTabKey = GlobalKey();
  final GlobalKey<PahapitTabViewState> _pahapitTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _profileLoading = true);
    try {
      final profile = await SupabaseService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _profileLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _profileLoading = false);
        showSugoBaySnackBar(context, 'Failed to load profile', isError: true);
      }
    }
  }

  void _handleRefresh() {
    switch (_currentIndex) {
      case 0:
        _foodTabKey.currentState?.refresh();
        break;
      case 1:
        _pahapitTabKey.currentState?.refresh();
        break;
      case 2:
        _loadProfile();
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.white),
            onPressed: () {
              showSugoBaySnackBar(context, 'Notifications coming soon');
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FoodTabView(key: _foodTabKey),
          PahapitTabView(key: _pahapitTabKey),
          _buildProfileTab(),
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
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_profileLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_userProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              icon: Icons.person_off,
              title: 'Profile not found',
              subtitle: 'Unable to load your profile',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SugoBayButton(
                text: 'Retry',
                onPressed: _loadProfile,
              ),
            ),
          ],
        ),
      );
    }

    final name = _userProfile!['name'] ?? 'Customer';
    final phone = _userProfile!['phone'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.teal,
            child: Text(
              name.toString().isNotEmpty ? name[0].toUpperCase() : 'C',
              style: AppTextStyles.heading.copyWith(fontSize: 36),
            ),
          ),
          const SizedBox(height: 16),
          Text(name, style: AppTextStyles.heading),
          const SizedBox(height: 4),
          Text(phone, style: AppTextStyles.body),
          const SizedBox(height: 32),
          SugoBayCard(
            onTap: () {
              showSugoBaySnackBar(context, 'Order history coming soon');
            },
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Order History', style: AppTextStyles.subheading),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SugoBayCard(
            onTap: () {
              showSugoBaySnackBar(context, 'Settings coming soon');
            },
            child: Row(
              children: [
                const Icon(Icons.settings, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Settings', style: AppTextStyles.subheading),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SugoBayButton(
            text: 'Logout',
            color: AppColors.coral,
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }
}
