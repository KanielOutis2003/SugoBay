import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import '../../shared/announcements_banner.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _HomeTab(),
          _OrdersTab(),
          _MessageTab(),
          _EWalletTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.navBarBg,
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home', c),
                _navItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders', c),
                _navItem(2, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Message', c),
                _navItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'E-Wallet', c),
                _navItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label, SugoColors c) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? SColors.primary : c.iconDefault,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? SColors.primary : c.iconDefault,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HOME TAB ────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Map<String, dynamic>> _merchants = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  static const _foodCategories = [
    {'name': 'Restaurant', 'icon': Icons.restaurant, 'emoji': '🍔'},
    {'name': 'Carenderia', 'icon': Icons.ramen_dining, 'emoji': '🍜'},
    {'name': 'Fast Food', 'icon': Icons.fastfood, 'emoji': '🍟'},
    {'name': 'BBQ', 'icon': Icons.outdoor_grill, 'emoji': '🍖'},
    {'name': 'Bakery', 'icon': Icons.bakery_dining, 'emoji': '🍰'},
    {'name': 'Cafe', 'icon': Icons.coffee, 'emoji': '☕'},
    {'name': 'More', 'icon': Icons.more_horiz, 'emoji': '🍽️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMerchants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchants() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.merchants()
          .select()
          .eq('is_approved', true)
          .eq('is_active', true);
      final data = (response as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _merchants = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredMerchants {
    final query = _searchController.text.toLowerCase();
    return _merchants.where((m) {
      final matchesCategory = _selectedCategory == 'All' ||
          (m['category'] ?? '').toString().toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (m['shop_name'] ?? '').toString().toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return SafeArea(
      child: RefreshIndicator(
        color: SColors.primary,
        onRefresh: _loadMerchants,
        child: CustomScrollView(
          slivers: [
            // ─── Header: Deliver to + icons ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: SColors.primary.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: SColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deliver to',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary)),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Ubay, Bohol',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, size: 20, color: SColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Cart
                    _headerIconButton(Icons.shopping_bag_outlined, c, onTap: () => context.push('/cart')),
                    const SizedBox(width: 8),
                    // Notifications
                    _headerIconButton(Icons.notifications_outlined, c),
                  ],
                ),
              ),
            ),

            // ─── Search Bar ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'What are you craving?',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary),
                      prefixIcon: Icon(Icons.search, color: c.textTertiary, size: 22),
                      suffixIcon: Icon(Icons.tune, color: SColors.primary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Announcements ───────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AnnouncementsBanner(),
              ),
            ),

            // ─── Special Offers ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Special Offers',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    GestureDetector(
                      onTap: () {},
                      child: Text('See All',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: SColors.primary)),
                    ),
                  ],
                ),
              ),
            ),

            // Promo Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A9D8F), Color(0xFF3DB8A9)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('30%',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                            Text('DISCOUNT ONLY\nVALID FOR TODAY!',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9), height: 1.3)),
                          ],
                        ),
                      ),
                      // Food emoji decoration
                      Positioned(
                        right: 16,
                        top: 20,
                        child: Text('🍔', style: TextStyle(fontSize: 64)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Food Categories ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _foodCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _foodCategories[index];
                    final isSelected = _selectedCategory == cat['name'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = isSelected ? 'All' : cat['name'] as String;
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SColors.primary.withValues(alpha: 0.15)
                                  : c.inputBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? SColors.primary : c.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(cat['emoji'] as String, style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat['name'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? SColors.primary : c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // ─── Services Row (Pahapit + Habal) ─────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _serviceCard(
                        emoji: '📦',
                        title: 'Pahapit',
                        subtitle: 'Send parcels',
                        color: SColors.coral,
                        onTap: () => context.push('/pahapit/new'),
                        c: c,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _serviceCard(
                        emoji: '🏍️',
                        title: 'Habal-habal',
                        subtitle: 'Book a ride',
                        color: SColors.gold,
                        onTap: () => context.push('/habal-habal/book'),
                        c: c,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Discount Guaranteed ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Discount Guaranteed!',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const SizedBox(width: 4),
                        const Text('🔥', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text('See All',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: SColors.primary)),
                    ),
                  ],
                ),
              ),
            ),

            // Horizontal promo cards
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: SColors.primary))
                    : _merchants.isEmpty
                        ? Center(child: Text('No offers yet', style: GoogleFonts.plusJakartaSans(color: c.textTertiary)))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            itemCount: _merchants.length.clamp(0, 6),
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final m = _merchants[index];
                              return _promoCard(m, c);
                            },
                          ),
              ),
            ),

            // ─── Recommended For You ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Recommended For You',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const SizedBox(width: 4),
                        const Text('😍', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text('See All',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: SColors.primary)),
                    ),
                  ],
                ),
              ),
            ),

            // Merchant list
            _isLoading
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: ShimmerList(count: 3, itemHeight: 88),
                    ),
                  )
                : _filteredMerchants.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.store_mall_directory, size: 48, color: c.textTertiary),
                                const SizedBox(height: 12),
                                Text('No merchants found',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final merchant = _filteredMerchants[index];
                            return Padding(
                              padding: EdgeInsets.fromLTRB(20, index == 0 ? 12 : 0, 20, 12),
                              child: _merchantCard(merchant, c),
                            );
                          },
                          childCount: _filteredMerchants.length.clamp(0, 10),
                        ),
                      ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _headerIconButton(IconData icon, SugoColors c, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, color: c.textPrimary, size: 22),
      ),
    );
  }

  Widget _serviceCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required SugoColors c,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text(subtitle,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _promoCard(Map<String, dynamic> merchant, SugoColors c) {
    final name = merchant['shop_name'] ?? 'Unknown';
    final category = merchant['category'] ?? '';
    final rating = (merchant['rating'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () => context.push('/merchant/${merchant['id']}'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: SColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.storefront, color: SColors.primary, size: 36)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('PROMO',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(category,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary)),
                      const Spacer(),
                      const Icon(Icons.star, color: SColors.gold, size: 13),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _merchantCard(Map<String, dynamic> merchant, SugoColors c) {
    final name = merchant['shop_name'] ?? 'Unknown';
    final category = merchant['category'] ?? '';
    final rating = (merchant['rating'] ?? 0).toDouble();
    final isOpen = merchant['is_open'] == true;

    return GestureDetector(
      onTap: () => context.push('/merchant/${merchant['id']}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront, color: SColors.primary, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(category,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: SColors.gold, size: 14),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isOpen ? SColors.success : SColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOpen ? 'Open' : 'Closed',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? SColors.success : SColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── ORDERS TAB ──────────────────────────────────────────────────────────────

class _OrdersTab extends StatefulWidget {
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final response = await SupabaseService.client
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _orders = (response as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 32, height: 32),
                const SizedBox(width: 10),
                Text('Orders',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const Spacer(),
                Icon(Icons.search, color: c.textPrimary, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: SColors.primary,
            unselectedLabelColor: c.textTertiary,
            indicatorColor: SColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 14),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList('active', c),
                _buildOrderList('completed', c),
                _buildOrderList('cancelled', c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(String status, SugoColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: SColors.primary));
    }

    final statusMap = {
      'active': ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'delivering'],
      'completed': ['delivered'],
      'cancelled': ['cancelled'],
    };

    final filtered = _orders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      return statusMap[status]?.contains(s) ?? false;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: c.textTertiary),
            const SizedBox(height: 16),
            Text('No $status orders',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const SizedBox(height: 4),
            Text('Your $status orders will appear here',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: SColors.primary,
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = filtered[index];
          return _orderCard(order, c);
        },
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order, SugoColors c) {
    final orderId = order['id'] ?? '';
    final status = order['status'] ?? 'pending';
    final total = (order['total'] ?? 0).toDouble();

    Color statusColor;
    switch (status.toString().toLowerCase()) {
      case 'cancelled':
        statusColor = SColors.error;
        break;
      case 'delivered':
        statusColor = SColors.success;
        break;
      default:
        statusColor = SColors.primary;
    }

    return GestureDetector(
      onTap: () => context.push('/order-tracking/$orderId'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fastfood_rounded, color: SColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${orderId.toString().substring(0, 8)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text('₱${total.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: SColors.primary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toString().replaceAll('_', ' '),
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MESSAGE TAB ─────────────────────────────────────────────────────────────

class _MessageTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 32, height: 32),
                const SizedBox(width: 10),
                Text('Message',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const Spacer(),
                Icon(Icons.search, color: c.textPrimary, size: 24),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: c.textTertiary),
                  const SizedBox(height: 16),
                  Text('No Messages Yet',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Chat with riders will appear here',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── E-WALLET TAB ────────────────────────────────────────────────────────────

class _EWalletTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 32, height: 32),
                  const SizedBox(width: 10),
                  Text('E-Wallet',
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Balance card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A9D8F), Color(0xFF21867A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SugoBay Wallet',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text('₱0.00',
                        style: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _walletAction(Icons.add, 'Top Up'),
                        const SizedBox(width: 16),
                        _walletAction(Icons.history, 'History'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Transaction History',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Icon(Icons.receipt_long_outlined, size: 48, color: c.textTertiary),
            const SizedBox(height: 12),
            Text('No transactions yet',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _walletAction(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── PROFILE TAB ─────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final user = SupabaseService.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 32, height: 32),
                  const SizedBox(width: 10),
                  Text('Profile',
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // User info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: SColors.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: SColors.primary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userMetadata?['full_name'] ?? 'User',
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
                        ),
                        Text(
                          user?.phone ?? user?.email ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit, color: SColors.primary, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: c.divider, indent: 20, endIndent: 20),

            // Menu items
            _profileMenuItem(Icons.favorite_border, 'My Favorite Restaurants', c, onTap: () {}),
            _profileMenuItem(Icons.local_offer_outlined, 'Special Offers & Promo', c, onTap: () {}),
            _profileMenuItem(Icons.payment, 'Payment Methods', c, onTap: () {}),

            Divider(color: c.divider, indent: 20, endIndent: 20),

            _profileMenuItem(Icons.person_outline, 'Profile', c, onTap: () => context.push('/settings')),
            _profileMenuItem(Icons.location_on_outlined, 'Address', c, onTap: () {}),
            _profileMenuItem(Icons.notifications_outlined, 'Notification', c, onTap: () {}),
            _profileMenuItem(Icons.report_problem_outlined, 'Report Issue', c,
                onTap: () => context.push('/complaint')),

            Divider(color: c.divider, indent: 20, endIndent: 20),

            _profileMenuItem(Icons.help_outline, 'Help Center', c, onTap: () {}),
            _profileMenuItem(Icons.people_outline, 'Invite Friends', c, onTap: () {}),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.logout, color: SColors.error),
                title: Text('Logout',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: SColors.error)),
                onTap: () => _handleLogout(context, c),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _profileMenuItem(IconData icon, String title, SugoColors c,
      {VoidCallback? onTap, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListTile(
        leading: Icon(icon, color: c.textSecondary, size: 22),
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary)),
        trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 14, color: c.textTertiary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleLogout(BuildContext context, SugoColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Logout',
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: SColors.error)),
            const SizedBox(height: 12),
            Text('Are you sure you want to logout?',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await SupabaseService.auth.signOut();
                        if (context.mounted) context.go('/landing');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text('Yes, Logout',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
