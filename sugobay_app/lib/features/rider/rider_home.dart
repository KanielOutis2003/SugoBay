import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  int _currentTab = 0;
  bool _isOnline = false;
  bool _isLoading = true;
  Timer? _gpsTimer;

  // Profile
  Map<String, dynamic>? _profile;

  // Jobs
  List<Map<String, dynamic>> _availableFoodOrders = [];
  List<Map<String, dynamic>> _availablePahapitJobs = [];
  List<Map<String, dynamic>> _myActiveFoodOrders = [];
  List<Map<String, dynamic>> _myActivePahapitJobs = [];

  // Stats
  int _todayDeliveries = 0;
  int _todayPahapitJobs = 0;
  double _todayEarnings = 0;
  double _averageRating = 0;
  int _totalJobs = 0;

  // Realtime
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _pahapitChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _ordersChannel?.unsubscribe();
    _pahapitChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadProfile(), _loadJobs(), _loadStats()]);
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error loading data: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final profile = await SupabaseService.users()
        .select()
        .eq('id', userId)
        .maybeSingle();

    // Check current online status
    final location = await SupabaseService.riderLocations()
        .select()
        .eq('rider_id', userId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _profile = profile;
        _isOnline = location?['is_online'] == true;
      });
    }
  }

  Future<void> _loadJobs() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    // Available food orders (pending or ready_for_pickup, no rider assigned)
    final availableFood = await SupabaseService.orders()
        .select('*, merchants(business_name)')
        .or('status.eq.pending,status.eq.ready_for_pickup')
        .isFilter('rider_id', null)
        .order('created_at', ascending: false);

    // Available pahapit requests (pending, no rider assigned)
    final availablePahapit = await SupabaseService.pahapitRequests()
        .select('*, users(name)')
        .eq('status', 'pending')
        .isFilter('rider_id', null)
        .order('created_at', ascending: false);

    // My active food orders
    final myFood = await SupabaseService.orders()
        .select('*, merchants(shop_name)')
        .eq('rider_id', userId)
        .not('status', 'in', '(delivered,cancelled)')
        .order('created_at', ascending: false);

    // My active pahapit jobs
    final myPahapit = await SupabaseService.pahapitRequests()
        .select('*, users(name)')
        .eq('rider_id', userId)
        .not('status', 'in', '(completed,cancelled)')
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _availableFoodOrders = List<Map<String, dynamic>>.from(availableFood);
        _availablePahapitJobs = List<Map<String, dynamic>>.from(
          availablePahapit,
        );
        _myActiveFoodOrders = List<Map<String, dynamic>>.from(myFood);
        _myActivePahapitJobs = List<Map<String, dynamic>>.from(myPahapit);
      });
    }
  }

  Future<void> _loadStats() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Today's food deliveries
    final foodToday = await SupabaseService.orders()
        .select('id, delivery_fee')
        .eq('rider_id', userId)
        .eq('status', 'delivered')
        .gte('delivered_at', '${today}T00:00:00')
        .lte('delivered_at', '${today}T23:59:59');

    // Today's pahapit completions
    final pahapitToday = await SupabaseService.pahapitRequests()
        .select('id, errand_fee, delivery_fee')
        .eq('rider_id', userId)
        .eq('status', 'completed')
        .gte('completed_at', '${today}T00:00:00')
        .lte('completed_at', '${today}T23:59:59');

    // Total jobs ever
    final allFood = await SupabaseService.orders()
        .select('id')
        .eq('rider_id', userId)
        .eq('status', 'delivered');
    final allPahapit = await SupabaseService.pahapitRequests()
        .select('id')
        .eq('rider_id', userId)
        .eq('status', 'completed');

    // Ratings
    final ratingsData = await SupabaseService.ratings()
        .select('rating')
        .eq('rated_user_id', userId);

    double earnings = 0;
    for (final order in foodToday) {
      final fee = (order['delivery_fee'] ?? 0).toDouble();
      earnings += fee * AppConstants.riderDeliveryFeePercent;
    }
    for (final job in pahapitToday) {
      final errandFee = (job['errand_fee'] ?? AppConstants.errandFee)
          .toDouble();
      final deliveryFee = (job['delivery_fee'] ?? 0).toDouble();
      earnings +=
          errandFee * (1 - AppConstants.errandFeeCutPercent) +
          deliveryFee * AppConstants.riderDeliveryFeePercent;
    }

    double avgRating = 0;
    if (ratingsData.isNotEmpty) {
      final total = ratingsData.fold<double>(
        0,
        (sum, r) => sum + (r['rating'] as num).toDouble(),
      );
      avgRating = total / ratingsData.length;
    }

    if (mounted) {
      setState(() {
        _todayDeliveries = foodToday.length;
        _todayPahapitJobs = pahapitToday.length;
        _todayEarnings = earnings;
        _totalJobs = allFood.length + allPahapit.length;
        _averageRating = avgRating;
      });
    }
  }

  void _subscribeRealtime() {
    _ordersChannel = SupabaseService.client
        .channel('rider_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _loadJobs(),
        )
        .subscribe();

    _pahapitChannel = SupabaseService.client
        .channel('rider_pahapit')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pahapit_requests',
          callback: (payload) => _loadJobs(),
        )
        .subscribe();
  }

  Future<void> _toggleOnline(bool value) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      if (value) {
        // Check location permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              showSugoBaySnackBar(
                context,
                'Location permission denied',
                isError: true,
              );
            }
            return;
          }
        }
        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            showSugoBaySnackBar(
              context,
              'Location permission permanently denied. Enable in settings.',
              isError: true,
            );
          }
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await SupabaseService.riderLocations().upsert({
          'rider_id': userId,
          'lat': position.latitude,
          'lng': position.longitude,
          'is_online': true,
          'updated_at': DateTime.now().toIso8601String(),
        });

        _startGpsTracking();
      } else {
        _gpsTimer?.cancel();
        _gpsTimer = null;

        await SupabaseService.riderLocations()
            .update({
              'is_online': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('rider_id', userId);
      }

      if (mounted) setState(() => _isOnline = value);
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  void _startGpsTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(
      Duration(seconds: AppConstants.gpsUpdateIntervalSeconds),
      (_) => _updateLocation(),
    );
  }

  Future<void> _updateLocation() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || !_isOnline) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await SupabaseService.riderLocations()
          .update({
            'lat': position.latitude,
            'lng': position.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('rider_id', userId);
    } catch (_) {
      // Silently fail GPS updates
    }
  }

  String get _statusLevel {
    if (_totalJobs >= 500) return 'Gold';
    if (_totalJobs >= 200) return 'Silver';
    if (_totalJobs >= 50) return 'Bronze';
    return 'Starter';
  }

  Future<void> _logout() async {
    await _toggleOnline(false);
    await SupabaseService.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: const Text('SugoBay Rider', style: AppTextStyles.subheading),
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: AppTextStyles.caption.copyWith(
                  color: _isOnline ? AppColors.success : AppColors.error,
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: _toggleOnline,
                activeColor: AppColors.success,
                inactiveThumbColor: AppColors.error,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.teal),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : IndexedStack(
              index: _currentTab,
              children: [
                _buildJobsTab(),
                _buildEarningsTab(),
                _buildProfileTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // ─── Stats Card ──────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return SugoBayCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${_todayDeliveries + _todayPahapitJobs}', "Today's Jobs"),
          Container(width: 1, height: 40, color: AppColors.darkGrey),
          _statItem(
            '\u20B1${_todayEarnings.toStringAsFixed(0)}',
            'Est. Earnings',
          ),
          Container(width: 1, height: 40, color: AppColors.darkGrey),
          _statItem(_statusLevel, 'Level'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.subheading.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  // ─── Jobs Tab ────────────────────────────────────────────────────────

  Widget _buildJobsTab() {
    final hasMyJobs =
        _myActiveFoodOrders.isNotEmpty || _myActivePahapitJobs.isNotEmpty;
    final hasAvailable =
        _availableFoodOrders.isNotEmpty || _availablePahapitJobs.isNotEmpty;

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCard(),
          const SizedBox(height: 20),

          // My Active Jobs
          if (hasMyJobs) ...[
            Text(
              'My Active Jobs',
              style: AppTextStyles.subheading.copyWith(color: AppColors.coral),
            ),
            const SizedBox(height: 12),
            ..._myActiveFoodOrders.map((o) => _buildFoodJobCard(o, mine: true)),
            ..._myActivePahapitJobs.map(
              (p) => _buildPahapitJobCard(p, mine: true),
            ),
            const SizedBox(height: 20),
          ],

          // Available Jobs
          Text(
            'Available Jobs',
            style: AppTextStyles.subheading.copyWith(color: AppColors.teal),
          ),
          const SizedBox(height: 12),

          if (!hasAvailable)
            const EmptyState(
              icon: Icons.hourglass_empty,
              title: 'No available jobs',
              subtitle: 'Pull to refresh or wait for new orders',
            ),

          ..._availableFoodOrders.map((o) => _buildFoodJobCard(o)),
          ..._availablePahapitJobs.map((p) => _buildPahapitJobCard(p)),
        ],
      ),
    );
  }

  Widget _buildFoodJobCard(Map<String, dynamic> order, {bool mine = false}) {
    final merchantName =
        order['merchants']?['business_name'] ?? 'Unknown Merchant';
    final status = order['status'] ?? 'pending';
    final total = (order['total_amount'] ?? 0).toDouble();
    final deliveryFee = (order['delivery_fee'] ?? 0).toDouble();
    final address = order['delivery_address'] ?? 'No address';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SugoBayCard(
        onTap: () => context.push('/job/food/${order['id']}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.coral.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant, color: AppColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchantName,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '\u20B1${total.toStringAsFixed(2)}',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fee: \u20B1${deliveryFee.toStringAsFixed(2)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.teal,
                        ),
                      ),
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

  Widget _buildPahapitJobCard(Map<String, dynamic> job, {bool mine = false}) {
    final storeName = job['store_name'] ?? 'Unknown Store';
    final status = job['status'] ?? 'pending';
    final budget = (job['budget_limit'] ?? 0).toDouble();
    final description = job['items_description'] ?? '';
    final truncatedDesc = description.length > 60
        ? '${description.substring(0, 60)}...'
        : description;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SugoBayCard(
        onTap: () => context.push('/job/pahapit/${job['id']}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.teal.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag, color: AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          storeName,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    truncatedDesc,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Budget: \u20B1${budget.toStringAsFixed(2)}',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fee: \u20B1${AppConstants.errandFee.toStringAsFixed(0)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.teal,
                        ),
                      ),
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

  // ─── Earnings Tab ────────────────────────────────────────────────────

  Widget _buildEarningsTab() {
    final totalToday = _todayDeliveries + _todayPahapitJobs;
    const dailyTarget = 8;
    final progress = (totalToday / dailyTarget).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsCard(),
        const SizedBox(height: 24),

        Text(
          "Today's Breakdown",
          style: AppTextStyles.subheading.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            children: [
              _earningsRow(
                Icons.restaurant,
                'Food Deliveries',
                '$_todayDeliveries',
                AppColors.coral,
              ),
              const Divider(color: AppColors.darkGrey, height: 24),
              _earningsRow(
                Icons.shopping_bag,
                'Pahapit Errands',
                '$_todayPahapitJobs',
                AppColors.teal,
              ),
              const Divider(color: AppColors.darkGrey, height: 24),
              _earningsRow(
                Icons.work,
                'Total Jobs',
                '$totalToday',
                AppColors.gold,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Daily Quota
        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Quota',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$totalToday / $dailyTarget',
                    style: AppTextStyles.body.copyWith(color: AppColors.gold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: AppColors.darkGrey,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.success : AppColors.teal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (progress >= 1.0)
                Text(
                  'Quota reached! Great job!',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                  ),
                )
              else
                Text(
                  '${dailyTarget - totalToday} more to hit daily target',
                  style: AppTextStyles.caption,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Estimated Earnings
        SugoBayCard(
          child: Column(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: AppColors.gold,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Estimated Earnings Today',
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '\u20B1${_todayEarnings.toStringAsFixed(2)}',
                style: AppTextStyles.heading.copyWith(color: AppColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _earningsRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
        Text(value, style: AppTextStyles.subheading.copyWith(color: color)),
      ],
    );
  }

  // ─── Profile Tab ─────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final name = _profile?['name'] ?? 'Rider';
    final phone = _profile?['phone'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.teal,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'R',
              style: AppTextStyles.heading.copyWith(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            name,
            style: AppTextStyles.heading.copyWith(fontSize: 22),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text(phone, style: AppTextStyles.caption)),
        const SizedBox(height: 24),

        SugoBayCard(
          child: Column(
            children: [
              _profileRow(Icons.work, 'Total Jobs', '$_totalJobs'),
              const Divider(color: AppColors.darkGrey, height: 20),
              _profileRow(
                Icons.star,
                'Average Rating',
                _averageRating > 0 ? _averageRating.toStringAsFixed(1) : 'N/A',
              ),
              const Divider(color: AppColors.darkGrey, height: 20),
              _profileRow(Icons.emoji_events, 'Status Level', _statusLevel),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SugoBayButton(
          text: 'Logout',
          onPressed: _logout,
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
