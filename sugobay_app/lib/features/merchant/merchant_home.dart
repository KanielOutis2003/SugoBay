import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/announcements_banner.dart';
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

  // Menu items for inline display
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, List<Map<String, dynamic>>> _groupedMenuItems = {};

  // Reviews
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;

  // Navigation
  int _currentNavIndex = 0;

  // Tabs
  late TabController _tabController;

  // Analytics
  int _totalOrdersAll = 0;
  double _totalRevenueAll = 0;
  int _thisWeekOrders = 0;
  double _thisWeekRevenue = 0;
  Map<String, int> _ordersByStatus = {};

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
        await Future.wait([_loadOrders(), _loadMenuItems(), _loadReviews(), _loadAnalytics()]);
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
      final activeRes = await SupabaseService.orders()
          .select('*, users!orders_customer_id_fkey(name, phone)')
          .eq('merchant_id', _merchantId)
          .not('status', 'in', '("delivered","cancelled")')
          .order('created_at', ascending: false);

      final historyRes = await SupabaseService.orders()
          .select('*, users!orders_customer_id_fkey(name, phone)')
          .eq('merchant_id', _merchantId)
          .inFilter('status', ['delivered', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(50);

      final allOrders = [...activeRes, ...historyRes];
      for (final order in allOrders) {
        final items = await SupabaseService.orderItems()
            .select('*, menu_items(name)')
            .eq('order_id', order['id']);
        order['items'] = items;
      }

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

  Future<void> _loadMenuItems() async {
    try {
      final res = await SupabaseService.menuItems()
          .select()
          .eq('merchant_id', _merchantId)
          .order('category')
          .order('name');

      final items = List<Map<String, dynamic>>.from(res);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final item in items) {
        final cat = (item['category'] ?? 'Uncategorized') as String;
        grouped.putIfAbsent(cat, () => []).add(item);
      }

      if (mounted) {
        setState(() {
          _menuItems = items;
          _groupedMenuItems = grouped;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    try {
      final res = await SupabaseService.client
          .from('reviews')
          .select('*')
          .eq('merchant_id', _merchantId)
          .order('created_at', ascending: false)
          .limit(50);

      final list = List<Map<String, dynamic>>.from(res);
      double avg = 0;
      if (list.isNotEmpty) {
        avg = list.fold<double>(0, (sum, r) => sum + (r['rating'] ?? 0).toDouble()) / list.length;
      }

      if (mounted) {
        setState(() {
          _reviews = list;
          _avgRating = avg;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAnalytics() async {
    try {
      final allOrders = await SupabaseService.orders()
          .select('status, total_amount, created_at')
          .eq('merchant_id', _merchantId);

      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

      int totalAll = allOrders.length;
      double revenueAll = 0;
      int weekOrders = 0;
      double weekRevenue = 0;
      final statusMap = <String, int>{};

      for (final o in allOrders) {
        final amount = (o['total_amount'] ?? 0).toDouble();
        final status = o['status'] ?? 'unknown';
        statusMap[status] = (statusMap[status] ?? 0) + 1;

        if (status == 'delivered') {
          revenueAll += amount;
        }
        final createdAt = o['created_at'] ?? '';
        if (createdAt.compareTo(weekAgo) >= 0) {
          weekOrders++;
          if (status == 'delivered') weekRevenue += amount;
        }
      }

      if (mounted) {
        setState(() {
          _totalOrdersAll = totalAll;
          _totalRevenueAll = revenueAll;
          _thisWeekOrders = weekOrders;
          _thisWeekRevenue = weekRevenue;
          _ordersByStatus = statusMap;
        });
      }
    } catch (_) {}
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
    if (mounted) context.go('/landing');
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

  Widget _buildOrderCard(Map<String, dynamic> order, SugoColors c) {
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SColors.primary,
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: c.textTertiary),
              const SizedBox(width: 6),
              Text(customerName,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _itemsSummary(order),
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\u20B1${total.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: SColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(_formatTime(createdAt),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: c.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(SugoColors c) {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.receipt_long,
          label: "Today's Orders",
          value: '$_todayOrdersCount',
          color: SColors.primary,
          c: c,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.payments_outlined,
          label: 'Revenue Today',
          value: '\u20B1${_todayRevenue.toStringAsFixed(0)}',
          color: SColors.gold,
          c: c,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.star_rounded,
          label: 'Rating',
          value: _rating > 0 ? _rating.toStringAsFixed(1) : '0',
          color: SColors.coral,
          c: c,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required SugoColors c,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: c.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalPending(SugoColors c) {
    return Scaffold(
      backgroundColor: c.bg,
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
                    color: SColors.gold.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 72,
                    color: SColors.gold,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Waiting for Admin Approval',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your merchant account is under review. You will be notified once approved.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: c.textSecondary),
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
                  color: SColors.coral,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersPage(SugoColors c) {
    return Column(
      children: [
        const AnnouncementsBanner(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatsRow(c),
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          indicatorColor: SColors.primary,
          labelColor: SColors.primary,
          unselectedLabelColor: c.textTertiary,
          tabs: [
            Tab(text: 'Active Orders (${_activeOrders.length})'),
            const Tab(text: 'Order History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _activeOrders.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Active Orders',
                      subtitle: 'New orders will appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: SColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _activeOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildOrderCard(_activeOrders[i], c),
                      ),
                    ),
              _historyOrders.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'No Order History',
                      subtitle: 'Completed and cancelled orders appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: SColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historyOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildOrderCard(_historyOrders[i], c),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage(SugoColors c) {
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
              color: c.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: SColors.primary.withAlpha(40),
                  child: const Icon(Icons.store, size: 40,
                      color: SColors.primary),
                ),
                const SizedBox(height: 14),
                Text(shopName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text(address,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SugoBayCard(
            child: Column(
              children: [
                _profileRow(Icons.receipt_long, 'Total Orders',
                    '$totalOrders', c),
                Divider(color: c.divider, height: 24),
                _profileRow(
                  Icons.star_rounded,
                  'Rating',
                  _rating > 0
                      ? '${_rating.toStringAsFixed(1)} / 5.0'
                      : '0 / 5.0',
                  c,
                ),
                Divider(color: c.divider, height: 24),
                _profileRow(Icons.phone_outlined, 'Phone', phone, c),
                if (email.isNotEmpty) ...[
                  Divider(color: c.divider, height: 24),
                  _profileRow(Icons.email_outlined, 'Email', email, c),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SugoBayButton(
            text: 'Logout',
            onPressed: _logout,
            color: SColors.coral,
          ),
        ],
      ),
    );
  }

  Widget _profileRow(
      IconData icon, String label, String value, SugoColors c) {
    return Row(
      children: [
        Icon(icon, color: SColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: c.textTertiary)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(
          child: CircularProgressIndicator(color: SColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56,
                    color: SColors.coral),
                const SizedBox(height: 16),
                Text('Something went wrong',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    )),
                const SizedBox(height: 8),
                Text(_error!,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SugoBayButton(text: 'Retry', onPressed: _loadMerchant),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isApproved) return _buildApprovalPending(c);

    final shopName = _merchant?['shop_name'] ?? 'My Shop';
    final isOpen = _merchant?['is_open'] == true;
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            if (_currentNavIndex == 0)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
                decoration: BoxDecoration(
                  color: c.cardBg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting \u{1F44B}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: c.textTertiary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shopName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _toggleIsOpen(!isOpen),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? SColors.success.withAlpha(20)
                                  : SColors.coral.withAlpha(20),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isOpen
                                    ? SColors.success.withAlpha(60)
                                    : SColors.coral.withAlpha(60),
                              ),
                              boxShadow: isOpen
                                  ? [
                                      BoxShadow(
                                          color:
                                              SColors.success.withAlpha(30),
                                          blurRadius: 12)
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOpen
                                        ? SColors.success
                                        : SColors.coral,
                                    boxShadow: isOpen
                                        ? [
                                            BoxShadow(
                                                color: SColors.success
                                                    .withAlpha(120),
                                                blurRadius: 6)
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOpen ? 'Open' : 'Closed',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isOpen
                                        ? SColors.success
                                        : SColors.coral,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded,
                              color: c.textTertiary, size: 20),
                          onPressed: _loadOrders,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
                    Text(
                      _currentNavIndex == 1
                          ? 'Menu'
                          : _currentNavIndex == 2
                              ? 'Analytics'
                              : _currentNavIndex == 3
                                  ? 'Reviews'
                                  : 'Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_currentNavIndex == 1)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: SColors.primary, size: 18),
                        ),
                        onPressed: () async {
                          await context.push('/menu-management');
                          _loadMenuItems();
                        },
                      ),
                  ],
                ),
              ),

            // Body
            Expanded(
              child: IndexedStack(
                index: _currentNavIndex,
                children: [
                  _buildOrdersPage(c),
                  _buildMenuPage(c),
                  _buildAnalyticsPage(c),
                  _buildReviewsPage(c),
                  _buildProfilePage(c),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.receipt_long_rounded, 'Orders', c),
                _navItem(1, Icons.restaurant_menu_rounded, 'Menu', c),
                _navItem(2, Icons.bar_chart_rounded, 'Analytics', c),
                _navItem(3, Icons.star_rounded, 'Reviews', c),
                _navItem(4, Icons.person_rounded, 'Profile', c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Analytics Page
  Widget _buildAnalyticsPage(SugoColors c) {
    final cancelledCount = _ordersByStatus['cancelled'] ?? 0;
    final deliveredCount = _ordersByStatus['delivered'] ?? 0;
    final pendingCount = _ordersByStatus['pending'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: SColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _buildStatCard(
                icon: Icons.shopping_bag_outlined,
                label: 'All-Time Orders',
                value: '$_totalOrdersAll',
                color: SColors.primary,
                c: c,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                icon: Icons.payments_outlined,
                label: 'Total Revenue',
                value: '\u20B1${_totalRevenueAll.toStringAsFixed(0)}',
                color: SColors.gold,
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCard(
                icon: Icons.calendar_today_rounded,
                label: 'This Week',
                value: '$_thisWeekOrders orders',
                color: SColors.coral,
                c: c,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Week Revenue',
                value: '\u20B1${_thisWeekRevenue.toStringAsFixed(0)}',
                color: SColors.primary,
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text('Order Status Breakdown',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 12),
          SugoBayCard(
            child: Column(
              children: [
                _analyticsRow('Delivered', deliveredCount, SColors.success, c),
                Divider(color: c.divider, height: 20),
                _analyticsRow('Pending', pendingCount, SColors.warning, c),
                Divider(color: c.divider, height: 20),
                _analyticsRow('Cancelled', cancelledCount, SColors.coral, c),
                if (_ordersByStatus.entries
                    .where((e) =>
                        !['delivered', 'pending', 'cancelled']
                            .contains(e.key))
                    .isNotEmpty) ...[
                  Divider(color: c.divider, height: 20),
                  ..._ordersByStatus.entries
                      .where((e) =>
                          !['delivered', 'pending', 'cancelled']
                              .contains(e.key))
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _analyticsRow(
                              e.key.replaceAll('_', ' '),
                              e.value,
                              SColors.primary,
                              c,
                            ),
                          )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Menu Summary',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          const SizedBox(height: 12),
          SugoBayCard(
            child: Column(
              children: [
                _analyticsRow(
                    'Total Items', _menuItems.length, SColors.primary, c),
                Divider(color: c.divider, height: 20),
                _analyticsRow(
                  'Available',
                  _menuItems
                      .where((i) => i['is_available'] == true)
                      .length,
                  SColors.success,
                  c,
                ),
                Divider(color: c.divider, height: 20),
                _analyticsRow(
                    'Categories', _groupedMenuItems.length, SColors.gold, c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsRow(
      String label, int count, Color color, SugoColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              label[0].toUpperCase() + label.substring(1),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textPrimary),
            ),
          ],
        ),
        Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Menu Page (inline)
  Widget _buildMenuPage(SugoColors c) {
    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 64,
                color: SColors.primary),
            const SizedBox(height: 16),
            Text('No Menu Items Yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                )),
            const SizedBox(height: 8),
            Text('Add items to your menu',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: c.textTertiary)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SugoBayButton(
                text: 'Open Menu Management',
                onPressed: () async {
                  await context.push('/menu-management');
                  _loadMenuItems();
                },
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenuItems,
      color: SColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _menuStat('Total', '${_menuItems.length}', c),
                _menuStat('Available',
                    '${_menuItems.where((i) => i['is_available'] == true).length}',
                    c),
                _menuStat(
                    'Categories', '${_groupedMenuItems.length}', c),
              ],
            ),
          ),
          ..._groupedMenuItems.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: SColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.key,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          )),
                      const SizedBox(width: 8),
                      Text('(${entry.value.length})',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: c.textTertiary)),
                    ],
                  ),
                ),
                ...entry.value.map((item) {
                  final isAvailable = item['is_available'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: (item['image_url'] != null &&
                                    (item['image_url'] as String)
                                        .isNotEmpty)
                                ? Image.network(item['image_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                            color: c.inputBg,
                                            child: Icon(Icons.fastfood,
                                                color: c.textTertiary,
                                                size: 20)))
                                : Container(
                                    color: c.inputBg,
                                    child: Icon(Icons.fastfood,
                                        color: c.textTertiary,
                                        size: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                  '\u20B1${(item['price'] ?? 0).toDouble().toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: SColors.gold)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isAvailable
                                    ? SColors.success
                                    : SColors.coral)
                                .withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAvailable ? 'Available' : 'Unavailable',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: isAvailable
                                  ? SColors.success
                                  : SColors.coral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _menuStat(String label, String value, SugoColors c) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SColors.primary,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary)),
      ],
    );
  }

  // Helpers

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _navItem(int index, IconData icon, String label, SugoColors c) {
    final isActive = _currentNavIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentNavIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 32 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive ? SColors.primary : null,
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: isActive ? SColors.primary : c.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? SColors.primary : c.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reviews Page
  Widget _buildReviewsPage(SugoColors c) {
    return RefreshIndicator(
      onRefresh: _loadReviews,
      color: SColors.primary,
      child: _reviews.isEmpty
          ? ListView(
              children: [
                SizedBox(
                    height: MediaQuery.of(context).size.height * 0.25),
                Icon(Icons.rate_review_outlined,
                    size: 64, color: c.textTertiary),
                const SizedBox(height: 16),
                Center(
                    child: Text('No Reviews Yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ))),
                const SizedBox(height: 8),
                Center(
                    child: Text('Customer reviews will appear here',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: c.textTertiary))),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Rating summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(
                            _avgRating.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: SColors.gold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(
                                5,
                                (i) => Icon(
                                      i < _avgRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: SColors.gold,
                                      size: 18,
                                    )),
                          ),
                          const SizedBox(height: 4),
                          Text('${_reviews.length} reviews',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: c.textTertiary)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: List.generate(5, (i) {
                            final star = 5 - i;
                            final count = _reviews
                                .where(
                                    (r) => (r['rating'] ?? 0) == star)
                                .length;
                            final pct = _reviews.isEmpty
                                ? 0.0
                                : count / _reviews.length;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text('$star',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: c.textTertiary)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star_rounded,
                                      color: SColors.gold, size: 12),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        backgroundColor: c.inputBg,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                SColors.gold),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 24,
                                    child: Text('$count',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: c.textTertiary)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                // Individual reviews
                ..._reviews.map((review) {
                  final name =
                      review['users']?['name'] ?? 'Customer';
                  final rating = (review['rating'] ?? 0).toInt();
                  final comment = review['comment'] ?? '';
                  final createdAt = review['created_at'];
                  String dateStr = '';
                  if (createdAt != null) {
                    try {
                      dateStr = DateFormat('MMM d, yyyy')
                          .format(DateTime.parse(createdAt).toLocal());
                    } catch (_) {}
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  SColors.primary.withAlpha(40),
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.plusJakartaSans(
                                  color: SColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: c.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      )),
                                  Text(dateStr,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: c.textTertiary)),
                                ],
                              ),
                            ),
                            Row(
                              children: List.generate(
                                  5,
                                  (i) => Icon(
                                        i < rating
                                            ? Icons.star_rounded
                                            : Icons
                                                .star_outline_rounded,
                                        color: SColors.gold,
                                        size: 16,
                                      )),
                            ),
                          ],
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(comment,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: c.textSecondary,
                                height: 1.4,
                              )),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
