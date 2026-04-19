import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _foodOrders = [];
  List<Map<String, dynamic>> _pahapitRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final food = await SupabaseService.orders()
          .select('*, merchants(shop_name)')
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final pahapit = await SupabaseService.pahapitRequests()
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _foodOrders = List<Map<String, dynamic>>.from(food);
          _pahapitRequests = List<Map<String, dynamic>>.from(pahapit);
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
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        title: const Text('Order History', style: AppTextStyles.subheading),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.teal),
            onPressed: _loadHistory,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Food Orders'),
            Tab(text: 'Pahapit'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFoodList(),
                _buildPahapitList(),
              ],
            ),
    );
  }

  Widget _buildFoodList() {
    if (_foodOrders.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant,
        title: 'No food orders yet',
        subtitle: 'Your food delivery history will appear here',
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _foodOrders.length,
        itemBuilder: (_, i) {
          final order = _foodOrders[i];
          final shopName =
              order['merchants']?['shop_name'] ?? 'Unknown Shop';
          final status = order['status'] ?? 'pending';
          final total = (order['total_amount'] ?? 0).toDouble();
          final date = DateTime.tryParse(order['created_at'] ?? '') ??
              DateTime.now();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SugoBayCard(
              onTap: () => context.push('/order-tracking/${order['id']}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant,
                          color: AppColors.coral, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(shopName,
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\u20B1${total.toStringAsFixed(2)}',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.gold)),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPahapitList() {
    if (_pahapitRequests.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_bag,
        title: 'No pahapit requests yet',
        subtitle: 'Your errand history will appear here',
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pahapitRequests.length,
        itemBuilder: (_, i) {
          final req = _pahapitRequests[i];
          final storeName = req['store_name'] ?? 'Unknown Store';
          final status = req['status'] ?? 'pending';
          final total = (req['total_amount'] ?? 0).toDouble();
          final date =
              DateTime.tryParse(req['created_at'] ?? '') ?? DateTime.now();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SugoBayCard(
              onTap: () => context.push('/pahapit/track/${req['id']}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag,
                          color: AppColors.teal, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(storeName,
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(req['items_description'] ?? '',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          total > 0
                              ? '\u20B1${total.toStringAsFixed(2)}'
                              : 'Pending',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.gold)),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
