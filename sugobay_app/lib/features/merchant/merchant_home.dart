import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;

  // Merchant data
  Map<String, dynamic>? _merchant;
  Map<String, dynamic>? _userProfile;
  bool _isApproved = false;
  String _merchantId = '';

  // Orders
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];

  // Stats
  int _todayOrdersCount = 0;
  double _todayRevenue = 0;
  double _rating = 0;

  // Navigation
  int _currentNavIndex = 0;

  // Tabs
  late TabController _tabController;

  // Realtime
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMerchant();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMerchant() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final merchant = await SupabaseService.merchants()
          .select()
          .eq('user_id', SupabaseService.currentUserId!)
          .single();

      final userProfile = await SupabaseService.users()
          .select()
          .eq('id', SupabaseService.currentUserId!)
          .single();

      _merchant = merchant;
      _userProfile = userProfile;
      _merchantId = merchant['id'];
      _isApproved = merchant['is_approved'] == true;
      _rating = (merchant['rating'] ?? 0).toDouble();

      if (_isApproved) {
        await _loadOrders();
        _subscribeToOrders();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrders() async {
    try {
      // Active orders
      final activeRes = await SupabaseService.orders()
          .select('*, users!orders_customer_id_fkey(name, phone)')
          .eq('merchant_id', _merchantId)
          .not('status', 'in', '("delivered","cancelled")')
          .order('created_at', ascending: false);

      // History orders
      final historyRes = await SupabaseService.orders()
          .select('*, users!orders_customer_id_fkey(name, phone)')
          .eq('merchant_id', _merchantId)
          .inFilter('status', ['delivered', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(50);

      // Load order items for each order
      final allOrders = [...activeRes, ...historyRes];
      for (final order in allOrders) {
        final items = await SupabaseService.orderItems()
            .select('*, menu_items(name)')
            .eq('order_id', order['id']);
        order['items'] = items;
      }

      // Today's stats
      final todayStart =
          DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final todayOrders = await SupabaseService.orders()
          .select('total_amount')
          .eq('merchant_id', _merchantId)
          .gte('created_at', '${todayStart}T00:00:00')
          .not('status', 'eq', 'cancelled');

      if (mounted) {
        setState(() {
          _activeOrders = List<Map<String, dynamic>>.from(activeRes);
          _historyOrders = List<Map<String, dynamic>>.from(historyRes);
          _todayOrdersCount = todayOrders.length;
          _todayRevenue = todayOrders.fold<double>(
            0,
            (sum, o) => sum + (o['total_amount'] ?? 0).toDouble(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to load orders: $e',
            isError: true);
      }
    }
  }

  void _subscribeToOrders() {
    _ordersChannel?.unsubscribe();
    _ordersChannel = SupabaseService.client
        .channel('merchant_orders_$_merchantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: _merchantId,
          ),
          callback: (payload) {
            _loadOrders();
          },
        )
        .subscribe();
  }

  Future<void> _toggleIsOpen(bool value) async {
    try {
      await SupabaseService.merchants()
          .update({'is_open': value}).eq('id', _merchantId);
      setState(() {
        _merchant!['is_open'] = value;
      });
      if (mounted) {
        showSugoBaySnackBar(
          context,
          value ? 'Shop is now open' : 'Shop is now closed',
        );
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to update: $e', isError: true);
      }
    }
  }

  Future<void> _logout() async {
    await SupabaseService.auth.signOut();
    if (mounted) context.go('/login');
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  String _itemsSummary(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    if (items.isEmpty) return 'No items';
    final summaries = items.map((item) {
      final name = item['menu_items']?['name'] ?? 'Item';
      final qty = item['quantity'] ?? 1;
      return '$qty x $name';
    }).toList();
    if (summaries.length <= 2) return summaries.join(', ');
    return '${summaries.take(2).join(', ')} +${summaries.length - 2} more';
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? '';
    final shortId =
        orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    final customer = order['users'];
    final customerName = customer?['name'] ?? 'Customer';
    final total = (order['total_amount'] ?? 0).toDouble();
    final status = order['status'] ?? 'pending';
    final createdAt = order['created_at'];

    return SugoBayCard(
      onTap: () => context.push('/merchant-order/$orderId'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$shortId',
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 15,
                  color: AppColors.teal,
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(customerName, style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _itemsSummary(order),
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\u20B1${total.toStringAsFixed(2)}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(_formatTime(createdAt), style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.receipt_long,
          label: "Today's Orders",
          value: '$_todayOrdersCount',
          color: AppColors.teal,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.payments_outlined,
          label: 'Revenue Today',
          value: '\u20B1${_todayRevenue.toStringAsFixed(0)}',
          color: AppColors.gold,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.star_rounded,
          label: 'Rating',
          value: _rating > 0 ? _rating.toStringAsFixed(1) : 'N/A',
          color: AppColors.coral,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalPending() {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 72,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Waiting for Admin Approval',
                  style: AppTextStyles.heading.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your merchant account is under review. You will be notified once approved.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SugoBayButton(
                  text: 'Refresh',
                  onPressed: _loadMerchant,
                  outlined: true,
                ),
                const SizedBox(height: 16),
                SugoBayButton(
                  text: 'Logout',
                  onPressed: _logout,
                  color: AppColors.coral,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatsRow(),
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Active Orders (${_activeOrders.length})'),
            const Tab(text: 'Order History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Active Orders
              _activeOrders.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Active Orders',
                      subtitle: 'New orders will appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: AppColors.teal,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _activeOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildOrderCard(_activeOrders[i]),
                      ),
                    ),

              // History Orders
              _historyOrders.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'No Order History',
                      subtitle: 'Completed and cancelled orders appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: AppColors.teal,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historyOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildOrderCard(_historyOrders[i]),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    final shopName = _merchant?['shop_name'] ?? 'My Shop';
    final address = _merchant?['address'] ?? '';
    final totalOrders = _merchant?['total_orders'] ?? 0;
    final phone = _userProfile?['phone'] ?? '';
    final email = _userProfile?['email'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkGrey.withAlpha(128)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.teal.withAlpha(40),
                  child:
                      const Icon(Icons.store, size: 40, color: AppColors.teal),
                ),
                const SizedBox(height: 14),
                Text(shopName, style: AppTextStyles.heading.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text(address, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SugoBayCard(
            child: Column(
              children: [
                _profileRow(Icons.receipt_long, 'Total Orders', '$totalOrders'),
                const Divider(color: AppColors.darkGrey, height: 24),
                _profileRow(
                  Icons.star_rounded,
                  'Rating',
                  _rating > 0 ? '${_rating.toStringAsFixed(1)} / 5.0' : 'N/A',
                ),
                const Divider(color: AppColors.darkGrey, height: 24),
                _profileRow(Icons.phone_outlined, 'Phone', phone),
                if (email.isNotEmpty) ...[
                  const Divider(color: AppColors.darkGrey, height: 24),
                  _profileRow(Icons.email_outlined, 'Email', email),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SugoBayButton(
            text: 'Logout',
            onPressed: _logout,
            color: AppColors.coral,
          ),
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.teal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.body.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.coral),
                const SizedBox(height: 16),
                Text('Something went wrong', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SugoBayButton(text: 'Retry', onPressed: _loadMerchant),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isApproved) return _buildApprovalPending();

    final shopName = _merchant?['shop_name'] ?? 'My Shop';
    final isOpen = _merchant?['is_open'] == true;

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: _currentNavIndex == 0
          ? AppBar(
              backgroundColor: AppColors.cardBg,
              title: Text(shopName, style: AppTextStyles.subheading),
              actions: [
                Row(
                  children: [
                    Text(
                      isOpen ? 'Open' : 'Closed',
                      style: AppTextStyles.caption.copyWith(
                        color: isOpen ? AppColors.success : AppColors.coral,
                      ),
                    ),
                    Switch(
                      value: isOpen,
                      onChanged: _toggleIsOpen,
                      activeThumbColor: AppColors.success,
                      inactiveThumbColor: AppColors.coral,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.teal),
                  onPressed: _loadOrders,
                ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.cardBg,
              title: Text(
                _currentNavIndex == 1 ? 'Menu' : 'Profile',
                style: AppTextStyles.subheading,
              ),
            ),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildOrdersPage(),
          // Menu tab - navigate to menu management
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu, size: 64, color: AppColors.teal),
                const SizedBox(height: 16),
                Text('Manage Your Menu', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                Text('Add, edit, or remove menu items', style: AppTextStyles.caption),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: SugoBayButton(
                    text: 'Open Menu Management',
                    onPressed: () => context.push('/menu-management'),
                  ),
                ),
              ],
            ),
          ),
          _buildProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
