import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/announcements_banner.dart';
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
  double? _lastLat;
  double? _lastLng;

  final MapController _mapController = MapController();
  LatLng? _currentPosition;

  Map<String, dynamic>? _profile;

  List<Map<String, dynamic>> _availableFoodOrders = [];
  List<Map<String, dynamic>> _availablePahapitJobs = [];
  List<Map<String, dynamic>> _myActiveFoodOrders = [];
  List<Map<String, dynamic>> _myActivePahapitJobs = [];
  List<Map<String, dynamic>> _availableHabalRides = [];
  List<Map<String, dynamic>> _myActiveHabalRides = [];

  int _todayDeliveries = 0;
  int _todayPahapitJobs = 0;
  double _todayEarnings = 0;
  double _averageRating = 0;
  int _totalJobs = 0;

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _pahapitChannel;
  RealtimeChannel? _habalChannel;

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
    _habalChannel?.unsubscribe();
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

    final profile =
        await SupabaseService.users().select().eq('id', userId).maybeSingle();
    final location = await SupabaseService.riderLocations()
        .select()
        .eq('rider_id', userId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _profile = profile;
        _isOnline = location?['is_online'] == true;
        if (location != null &&
            location['lat'] != null &&
            location['lng'] != null) {
          _currentPosition = LatLng(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          );
        }
      });
    }
  }

  Future<void> _loadJobs() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final availableFood = await SupabaseService.orders()
        .select('*, merchants(shop_name)')
        .or('status.eq.pending,status.eq.ready_for_pickup')
        .isFilter('rider_id', null)
        .order('created_at', ascending: false);

    final availablePahapit = await SupabaseService.pahapitRequests()
        .select('*')
        .eq('status', 'pending')
        .isFilter('rider_id', null)
        .order('created_at', ascending: false);

    final myFood = await SupabaseService.orders()
        .select('*, merchants(shop_name)')
        .eq('rider_id', userId)
        .not('status', 'in', '(delivered,cancelled)')
        .order('created_at', ascending: false);

    final myPahapit = await SupabaseService.pahapitRequests()
        .select('*')
        .eq('rider_id', userId)
        .not('status', 'in', '(completed,cancelled)')
        .order('created_at', ascending: false);

    List availableHabal = [];
    List myHabal = [];
    try {
      availableHabal = await SupabaseService.habalHabalRides()
          .select('*')
          .eq('status', 'searching')
          .isFilter('rider_id', null)
          .order('created_at', ascending: false);
      myHabal = await SupabaseService.habalHabalRides()
          .select('*')
          .eq('rider_id', userId)
          .not('status', 'in', '(completed,cancelled)')
          .order('created_at', ascending: false);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _availableFoodOrders =
            List<Map<String, dynamic>>.from(availableFood);
        _availablePahapitJobs =
            List<Map<String, dynamic>>.from(availablePahapit);
        _myActiveFoodOrders = List<Map<String, dynamic>>.from(myFood);
        _myActivePahapitJobs =
            List<Map<String, dynamic>>.from(myPahapit);
        _availableHabalRides =
            List<Map<String, dynamic>>.from(availableHabal);
        _myActiveHabalRides = List<Map<String, dynamic>>.from(myHabal);
      });
    }
  }

  Future<void> _loadStats() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    final foodToday = await SupabaseService.orders()
        .select('id, delivery_fee')
        .eq('rider_id', userId)
        .eq('status', 'delivered')
        .gte('delivered_at', '${today}T00:00:00')
        .lte('delivered_at', '${today}T23:59:59');

    final pahapitToday = await SupabaseService.pahapitRequests()
        .select('id, errand_fee, delivery_fee')
        .eq('rider_id', userId)
        .eq('status', 'completed')
        .gte('completed_at', '${today}T00:00:00')
        .lte('completed_at', '${today}T23:59:59');

    final allFood = await SupabaseService.orders()
        .select('id')
        .eq('rider_id', userId)
        .eq('status', 'delivered');
    final allPahapit = await SupabaseService.pahapitRequests()
        .select('id')
        .eq('rider_id', userId)
        .eq('status', 'completed');

    final riderOrderIds = [
      ...allFood.map((o) => o['id']),
      ...allPahapit.map((p) => p['id'])
    ];
    List<dynamic> ratingsData = [];
    if (riderOrderIds.isNotEmpty) {
      final foodRatings = await SupabaseService.ratings()
          .select('rider_rating')
          .not('rider_rating', 'is', null)
          .inFilter('order_id', allFood.map((o) => o['id']).toList());
      final pahapitRatings = await SupabaseService.ratings()
          .select('rider_rating')
          .not('rider_rating', 'is', null)
          .inFilter(
              'pahapit_id', allPahapit.map((p) => p['id']).toList());
      ratingsData = [...foodRatings, ...pahapitRatings];
    }

    double earnings = 0;
    for (final order in foodToday) {
      final fee = (order['delivery_fee'] ?? 0).toDouble();
      earnings += fee * AppConstants.riderDeliveryFeePercent;
    }
    for (final job in pahapitToday) {
      final errandFee =
          (job['errand_fee'] ?? AppConstants.errandFee).toDouble();
      final deliveryFee = (job['delivery_fee'] ?? 0).toDouble();
      earnings += errandFee * (1 - AppConstants.errandFeeCutPercent) +
          deliveryFee * AppConstants.riderDeliveryFeePercent;
    }

    double avgRating = 0;
    if (ratingsData.isNotEmpty) {
      final total = ratingsData.fold<double>(
          0, (sum, r) => sum + (r['rider_rating'] as num).toDouble());
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

    _habalChannel = SupabaseService.client
        .channel('rider_habal')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'habal_habal_rides',
          callback: (payload) => _loadJobs(),
        )
        .subscribe();
  }

  Future<void> _toggleOnline(bool value) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      if (value) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              showSugoBaySnackBar(context, 'Location permission denied',
                  isError: true);
            }
            return;
          }
        }
        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            showSugoBaySnackBar(context,
                'Location permission permanently denied. Enable in settings.',
                isError: true);
          }
          return;
        }

        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentPosition =
                LatLng(position.latitude, position.longitude);
          });
        }

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
      final position = await Geolocator.getCurrentPosition();
      if (_lastLat != null && _lastLng != null) {
        final distance = Geolocator.distanceBetween(
          _lastLat!,
          _lastLng!,
          position.latitude,
          position.longitude,
        );
        if (distance < AppConstants.gpsMinDistanceMeters) return;
      }

      _lastLat = position.latitude;
      _lastLng = position.longitude;

      if (mounted) {
        setState(() {
          _currentPosition =
              LatLng(position.latitude, position.longitude);
        });
      }

      await SupabaseService.riderLocations()
          .update({
            'lat': position.latitude,
            'lng': position.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('rider_id', userId);
    } catch (_) {}
  }

  String get _statusLevel {
    if (_totalJobs >= 500 && _averageRating >= 4.7) return 'Elite';
    if (_totalJobs >= 200) return 'Trusted';
    if (_totalJobs >= 50) return 'Regular';
    return 'Rookie';
  }

  Future<void> _logout() async {
    await _toggleOnline(false);
    await SupabaseService.auth.signOut();
    if (mounted) context.go('/landing');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.cardBg,
        title: Text('SugoBay Rider',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: _isOnline ? SColors.success : SColors.error,
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: _toggleOnline,
                activeThumbColor: SColors.success,
                inactiveThumbColor: SColors.error,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: SColors.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: SColors.primary))
          : IndexedStack(
              index: _currentTab,
              children: [
                _buildJobsTab(c, isDark),
                _buildMapTab(c, isDark),
                _buildEarningsTab(c),
                _buildProfileTab(c),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        backgroundColor: c.cardBg,
        selectedItemColor: SColors.primary,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Earnings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // Map Tab
  Widget _buildMapTab(SugoColors c, bool isDark) {
    final center =
        _currentPosition ?? const LatLng(10.0581, 124.0474);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: isDark ? const ['a', 'b', 'c', 'd'] : const [],
              userAgentPackageName: 'com.sugobay.app',
              retinaMode: isDark,
            ),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    point: _currentPosition!,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.navigation,
                      color: SColors.primary,
                      size: 36,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: c.cardBg,
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, 15.0);
              }
            },
            child: const Icon(Icons.my_location, color: SColors.primary),
          ),
        ),
        if (_currentPosition == null)
          Center(
            child: SugoBayCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off,
                        color: SColors.coral, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _isOnline
                          ? 'Getting your location...'
                          : 'Go online to see your location',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: c.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Stats Card
  Widget _buildStatsCard(SugoColors c) {
    return SugoBayCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(c,
              '${_todayDeliveries + _todayPahapitJobs}', "Today's Jobs"),
          Container(width: 1, height: 40, color: c.divider),
          _statItem(c,
              '\u20B1${_todayEarnings.toStringAsFixed(0)}', 'Est. Earnings'),
          Container(width: 1, height: 40, color: c.divider),
          _statItem(c, _statusLevel, 'Level'),
        ],
      ),
    );
  }

  Widget _statItem(SugoColors c, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SColors.gold,
            )),
        const SizedBox(height: 4),
        Text(label,
            style:
                GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary)),
      ],
    );
  }

  // Jobs Tab
  Widget _buildJobsTab(SugoColors c, bool isDark) {
    final hasMyJobs = _myActiveFoodOrders.isNotEmpty ||
        _myActivePahapitJobs.isNotEmpty ||
        _myActiveHabalRides.isNotEmpty;
    final hasAvailable = _availableFoodOrders.isNotEmpty ||
        _availablePahapitJobs.isNotEmpty ||
        _availableHabalRides.isNotEmpty;

    return RefreshIndicator(
      color: SColors.primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AnnouncementsBanner(),
          _buildStatsCard(c),
          const SizedBox(height: 20),

          if (hasMyJobs) ...[
            Text('My Active Jobs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SColors.coral,
                )),
            const SizedBox(height: 12),
            ..._myActiveFoodOrders
                .map((o) => _buildFoodJobCard(c, o, mine: true)),
            ..._myActivePahapitJobs
                .map((p) => _buildPahapitJobCard(c, p, mine: true)),
            ..._myActiveHabalRides
                .map((r) => _buildHabalJobCard(c, r, mine: true)),
            const SizedBox(height: 20),
          ],

          Text('Available Jobs',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SColors.primary,
              )),
          const SizedBox(height: 12),

          if (!hasAvailable)
            const EmptyState(
              icon: Icons.hourglass_empty,
              title: 'No available jobs',
              subtitle: 'Pull to refresh or wait for new orders',
            ),

          ..._availableFoodOrders.map((o) => _buildFoodJobCard(c, o)),
          ..._availablePahapitJobs
              .map((p) => _buildPahapitJobCard(c, p)),
          ..._availableHabalRides
              .map((r) => _buildHabalJobCard(c, r)),
        ],
      ),
    );
  }

  Widget _buildFoodJobCard(SugoColors c, Map<String, dynamic> order,
      {bool mine = false}) {
    final merchantName =
        order['merchants']?['shop_name'] ?? 'Unknown Merchant';
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
                color: SColors.coral.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.restaurant, color: SColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(merchantName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            )),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('\u20B1${total.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: SColors.gold)),
                      const Spacer(),
                      Text(
                          'Fee: \u20B1${deliveryFee.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: SColors.primary)),
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

  Widget _buildPahapitJobCard(SugoColors c, Map<String, dynamic> job,
      {bool mine = false}) {
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
                color: SColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag,
                  color: SColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(storeName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            )),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(truncatedDesc,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                          'Budget: \u20B1${budget.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: SColors.gold)),
                      const Spacer(),
                      Text(
                          'Fee: \u20B1${AppConstants.errandFee.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: SColors.primary)),
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

  Widget _buildHabalJobCard(SugoColors c, Map<String, dynamic> ride,
      {bool mine = false}) {
    final customerName = ride['users']?['name'] ?? 'Customer';
    final status = ride['status'] ?? 'searching';
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final pickup = ride['pickup_address'] as String? ?? 'Pickup';
    final dropoff = ride['dropoff_address'] as String? ?? 'Drop-off';
    final distance =
        (ride['distance_km'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SugoBayCard(
        onTap: mine
            ? () => context.push('/rider-habal/${ride['id']}')
            : () => _acceptHabalRide(ride),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SColors.gold.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.motorcycle, color: SColors.gold),
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
                            mine ? customerName : 'Habal-habal Ride',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            )),
                      ),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          color: SColors.primary, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(pickup,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: c.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: SColors.coral, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(dropoff,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: c.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('\u20B1${fare.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: SColors.gold)),
                      const SizedBox(width: 12),
                      Text('${distance.toStringAsFixed(1)} km',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: c.textTertiary)),
                      if (!mine) ...[
                        const Spacer(),
                        Text('Tap to accept',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: SColors.primary)),
                      ],
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

  Future<void> _acceptHabalRide(Map<String, dynamic> ride) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.habalHabalRides()
          .update({
            'rider_id': userId,
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ride['id'])
          .eq('status', 'searching');

      if (mounted) {
        showSugoBaySnackBar(context, 'Ride accepted!');
        _loadJobs();
        context.push('/rider-habal/${ride['id']}');
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to accept ride: $e',
            isError: true);
      }
    }
  }

  // Earnings Tab
  Widget _buildEarningsTab(SugoColors c) {
    final totalToday = _todayDeliveries + _todayPahapitJobs;
    const dailyTarget = 8;
    final progress = (totalToday / dailyTarget).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsCard(c),
        const SizedBox(height: 24),

        Text("Today's Breakdown",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SColors.gold,
            )),
        const SizedBox(height: 16),

        SugoBayCard(
          child: Column(
            children: [
              _earningsRow(c, Icons.restaurant, 'Food Deliveries',
                  '$_todayDeliveries', SColors.coral),
              Divider(color: c.divider, height: 24),
              _earningsRow(c, Icons.shopping_bag, 'Pahapit Errands',
                  '$_todayPahapitJobs', SColors.primary),
              Divider(color: c.divider, height: 24),
              _earningsRow(c, Icons.work, 'Total Jobs',
                  '$totalToday', SColors.gold),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SugoBayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daily Quota',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      )),
                  Text('$totalToday / $dailyTarget',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: SColors.gold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? SColors.success
                        : SColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (progress >= 1.0)
                Text('Quota reached! Great job!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: SColors.success))
              else
                Text(
                    '${dailyTarget - totalToday} more to hit daily target',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SugoBayCard(
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: SColors.gold, size: 40),
              const SizedBox(height: 12),
              Text('Estimated Earnings Today',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 8),
              Text('\u20B1${_todayEarnings.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: SColors.gold,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _earningsRow(SugoColors c, IconData icon, String label,
      String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textPrimary))),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            )),
      ],
    );
  }

  // Profile Tab
  Widget _buildProfileTab(SugoColors c) {
    final name = _profile?['name'] ?? 'Rider';
    final phone = _profile?['phone'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: SColors.primary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'R',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
            child: Text(name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ))),
        const SizedBox(height: 4),
        Center(
            child: Text(phone,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: c.textTertiary))),
        const SizedBox(height: 24),

        SugoBayCard(
          child: Column(
            children: [
              _profileRow(c, Icons.work, 'Total Jobs', '$_totalJobs'),
              Divider(color: c.divider, height: 20),
              _profileRow(c, Icons.star, 'Average Rating',
                  _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '0'),
              Divider(color: c.divider, height: 20),
              _profileRow(
                  c, Icons.emoji_events, 'Status Level', _statusLevel),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SugoBayButton(
          text: 'My Shift Schedule',
          onPressed: () => context.push('/shift-schedule'),
        ),
        const SizedBox(height: 16),

        SugoBayButton(
          text: 'Logout',
          onPressed: _logout,
          color: SColors.error,
        ),
      ],
    );
  }

  Widget _profileRow(
      SugoColors c, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: SColors.gold, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textPrimary))),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: SColors.gold,
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }
}
