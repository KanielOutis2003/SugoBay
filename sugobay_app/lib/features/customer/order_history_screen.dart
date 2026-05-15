import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _activeOrders => _allOrders
      .where((o) => !['delivered', 'completed', 'cancelled']
          .contains(o['status']))
      .toList();

  List<Map<String, dynamic>> get _completedOrders => _allOrders
      .where((o) =>
          o['status'] == 'delivered' || o['status'] == 'completed')
      .toList();

  List<Map<String, dynamic>> get _cancelledOrders =>
      _allOrders.where((o) => o['status'] == 'cancelled').toList();

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final food = await SupabaseService.orders()
          .select('*, merchants(shop_name, logo_url)')
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final pahapit = await SupabaseService.pahapitRequests()
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final combined = <Map<String, dynamic>>[];
      for (final o in food) {
        combined.add({
          ...Map<String, dynamic>.from(o),
          '_type': 'food',
        });
      }
      for (final p in pahapit) {
        combined.add({
          ...Map<String, dynamic>.from(p),
          '_type': 'pahapit',
        });
      }
      combined.sort((a, b) =>
          (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

      if (mounted) {
        setState(() {
          _allOrders = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSugoBaySnackBar(context, 'Failed to load history', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: SColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Orders',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadHistory,
                    child: Icon(Icons.search, color: c.textPrimary, size: 26),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: c.border, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: SColors.primary,
                indicatorWeight: 3,
                labelColor: SColors.primary,
                unselectedLabelColor: c.textTertiary,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),

            // ── Tab Content ──
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: SColors.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrderList(_activeOrders, 'active'),
                        _buildOrderList(_completedOrders, 'completed'),
                        _buildOrderList(_cancelledOrders, 'cancelled'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders, String tab) {
    if (orders.isEmpty) {
      return _buildEmptyState(tab);
    }

    return RefreshIndicator(
      color: SColors.primary,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: orders.length,
        itemBuilder: (_, i) => _buildOrderCard(orders[i], tab),
      ),
    );
  }

  Widget _buildEmptyState(String tab) {
    final c = context.sc;
    String title;
    String subtitle;

    switch (tab) {
      case 'active':
        title = 'Empty';
        subtitle = 'You do not have an active order at this time';
        break;
      case 'completed':
        title = 'No completed orders';
        subtitle = 'Your completed orders will appear here';
        break;
      default:
        title = 'No cancelled orders';
        subtitle = 'Your cancelled orders will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 56,
              color: c.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: c.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String tab) {
    final c = context.sc;
    final type = order['_type'] ?? 'food';
    final status = order['status'] ?? 'pending';
    final total = (order['total_amount'] ?? 0).toDouble();

    String name;
    String? imageUrl;
    int itemCount = 0;

    if (type == 'food') {
      name = order['merchants']?['shop_name'] ?? 'Unknown Shop';
      imageUrl = order['merchants']?['logo_url'];
      final items = order['items'];
      if (items is List) {
        itemCount = items.length;
      }
    } else {
      name = order['store_name'] ?? 'Pahapit Errand';
      itemCount = 1;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (type == 'food') {
            context.push('/order-tracking/${order['id']}');
          } else {
            context.push('/pahapit/track/${order['id']}');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top row: image + info ──
              Row(
                children: [
                  // Food image
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Center(
                              child: Icon(Icons.restaurant,
                                  color: c.textTertiary, size: 28),
                            ),
                            errorWidget: (_, _, _) => Center(
                              child: Icon(
                                type == 'food'
                                    ? Icons.restaurant
                                    : Icons.shopping_bag,
                                color: c.textTertiary,
                                size: 28,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              type == 'food'
                                  ? Icons.restaurant
                                  : Icons.shopping_bag,
                              color: c.textTertiary,
                              size: 28,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  // Name + details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount item${itemCount != 1 ? 's' : ''}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: c.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '\u20B1${total.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: SColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildStatusChip(status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Action buttons for completed orders ──
              if (tab == 'completed') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Leave review action
                        },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: SColors.primary, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              'Leave a Review',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: SColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (type == 'food') {
                            final merchantId = order['merchant_id'];
                            if (merchantId != null) {
                              context.push('/merchant/$merchantId');
                            }
                          }
                        },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: SColors.primary,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    SColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Order Again',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = SColors.warning;
        label = 'Pending';
        break;
      case 'accepted':
      case 'preparing':
      case 'buying':
        color = SColors.gold;
        label = status[0].toUpperCase() + status.substring(1);
        break;
      case 'ready_for_pickup':
      case 'picked_up':
      case 'delivering':
        color = SColors.primary;
        label = status.replaceAll('_', ' ');
        label = label[0].toUpperCase() + label.substring(1);
        break;
      case 'delivered':
      case 'completed':
        color = SColors.success;
        label = 'Completed';
        break;
      case 'cancelled':
        color = SColors.error;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
