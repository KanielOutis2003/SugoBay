import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cart_provider.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';

class MerchantDetailScreen extends StatefulWidget {
  final String merchantId;

  const MerchantDetailScreen({super.key, required this.merchantId});

  @override
  State<MerchantDetailScreen> createState() => _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends State<MerchantDetailScreen> {
  Map<String, dynamic>? _merchant;
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  String? _error;

  final Map<String, CartItem> _cart = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final merchantRes = await SupabaseService.merchants()
          .select()
          .eq('id', widget.merchantId)
          .maybeSingle();
      final menuRes = await SupabaseService.menuItems()
          .select()
          .eq('merchant_id', widget.merchantId)
          .eq('is_available', true);

      if (mounted) {
        setState(() {
          _merchant = merchantRes;
          _menuItems = (menuRes as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load: $e';
          _isLoading = false;
        });
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> get _groupedItems {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _menuItems) {
      final cat = (item['category'] ?? 'Other').toString();
      groups.putIfAbsent(cat, () => []).add(item);
    }
    return groups;
  }

  int get _cartItemCount =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get _cartTotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  void _addToCart(Map<String, dynamic> menuItem) {
    final id = menuItem['id'].toString();
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!.quantity++;
      } else {
        _cart[id] = CartItem(
          id: id,
          name: menuItem['name'] ?? '',
          price: (menuItem['price'] ?? 0).toDouble(),
          quantity: 1,
          imageUrl: menuItem['image_url'],
        );
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      if (_cart.containsKey(id) && _cart[id]!.quantity > 1) {
        _cart[id]!.quantity--;
      } else {
        _cart.remove(id);
      }
    });
  }

  void _showAddToBasketSheet(Map<String, dynamic> item) {
    final c = context.sc;
    final name = item['name'] ?? '';
    final description = item['description'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final imageUrl = item['image_url'];
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              // Food image
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: _buildImage(imageUrl, 200, c),
                ),
              ),
              const SizedBox(height: 20),
              Text(name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary, height: 1.5),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              // Quantity selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundQtyButton(Icons.remove, () {
                    if (qty > 1) setSheetState(() => qty--);
                  }, c),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('$qty',
                        style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  ),
                  _roundQtyButton(Icons.add, () => setSheetState(() => qty++), c),
                ],
              ),
              const SizedBox(height: 20),
              // Note field
              Container(
                decoration: BoxDecoration(
                  color: c.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: TextField(
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Note to Restaurant (optional)',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Add to basket button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    for (int i = 0; i < qty; i++) {
                      _addToCart(item);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: SColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    'Add to Basket - \u20B1${(price * qty).toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator(color: SColors.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: SColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SugoBayButton(text: 'Retry', onPressed: _loadData),
              ),
            ],
          ),
        ),
      );
    }

    if (_merchant == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const EmptyState(icon: Icons.store, title: 'Merchant not found'),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          // Hero image + back/fav buttons
          _buildHeroSliver(c),
          // Merchant info
          SliverToBoxAdapter(child: _buildMerchantInfo(c)),
          // "For You" horizontal section
          if (_menuItems.length > 2) ...[
            SliverToBoxAdapter(child: _buildForYouSection(c)),
          ],
          // Menu sections
          ..._buildMenuSections(c),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _cartItemCount > 0 ? _buildCartBar(c) : null,
    );
  }

  Widget _buildHeroSliver(SugoColors c) {
    final imageUrl = _merchant?['image_url'];
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: c.bg,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: c.bg.withValues(alpha: 0.8),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CircleAvatar(
            backgroundColor: c.bg.withValues(alpha: 0.8),
            child: Icon(Icons.favorite_border, color: c.textPrimary, size: 20),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildImage(imageUrl, 300, c),
      ),
    );
  }

  Widget _buildMerchantInfo(SugoColors c) {
    final m = _merchant!;
    final rating = (m['rating'] ?? 0).toDouble();
    final isOpen = m['is_open'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m['shop_name'] ?? '',
                    style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: c.textTertiary),
            ],
          ),
          const SizedBox(height: 10),
          // Rating row
          Row(
            children: [
              const Icon(Icons.star, color: SColors.gold, size: 18),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
              Text(' (reviews)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          // Distance row
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: SColors.primary),
              const SizedBox(width: 4),
              Text(m['address'] ?? 'Ubay, Bohol',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          const SizedBox(height: 8),
          // Delivery info
          Row(
            children: [
              Icon(Icons.delivery_dining, size: 16, color: SColors.primary),
              const SizedBox(width: 4),
              Text(isOpen ? 'Delivery Now' : 'Currently Closed',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isOpen ? SColors.primary : SColors.error)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: c.divider),
        ],
      ),
    );
  }

  Widget _buildForYouSection(SugoColors c) {
    final forYou = _menuItems.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text('For You',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: forYou.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = forYou[index];
              return _forYouCard(item, c);
            },
          ),
        ),
      ],
    );
  }

  Widget _forYouCard(Map<String, dynamic> item, SugoColors c) {
    final name = item['name'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final imageUrl = item['image_url'];

    return GestureDetector(
      onTap: () => _showAddToBasketSheet(item),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(height: 100, width: 140, child: _buildImage(imageUrl, 100, c)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('\u20B1${price.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: SColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuSections(SugoColors c) {
    final groups = _groupedItems;
    if (groups.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: EmptyState(icon: Icons.restaurant_menu, title: 'No menu items available'),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final entry in groups.entries) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(entry.key,
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ),
      ));
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildMenuItem(entry.value[index], c),
          childCount: entry.value.length,
        ),
      ));
    }
    return slivers;
  }

  Widget _buildMenuItem(Map<String, dynamic> item, SugoColors c) {
    final id = item['id'].toString();
    final name = item['name'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final imageUrl = item['image_url'];
    final qty = _cart[id]?.quantity ?? 0;

    return GestureDetector(
      onTap: () => _showAddToBasketSheet(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 64, height: 64, child: _buildImage(imageUrl, 64, c)),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text('\u20B1${price.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: SColors.primary)),
                ],
              ),
            ),
            // Quantity controls
            if (qty == 0)
              GestureDetector(
                onTap: () => _addToCart(item),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _roundQtyButton(Icons.remove, () => _removeFromCart(id), c),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$qty',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  ),
                  _roundQtyButton(Icons.add, () => _addToCart(item), c),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBar(SugoColors c) {
    return GestureDetector(
      onTap: () {
        ProviderScope.containerOf(context).read(cartProvider.notifier).setCart(
              Map.from(_cart),
              widget.merchantId,
              _merchant?['shop_name'] ?? 'Merchant',
            );
        context.push('/cart');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        margin: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: SColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: SColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$_cartItemCount',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Text('View Cart',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            const Spacer(),
            Text('\u20B1${_cartTotal.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _roundQtyButton(IconData icon, VoidCallback onTap, SugoColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, color: SColors.primary, size: 18),
      ),
    );
  }

  Widget _buildImage(String? imageUrl, double height, SugoColors c) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          color: c.inputBg,
          child: Icon(Icons.fastfood, color: c.textTertiary, size: 28),
        ),
        errorWidget: (_, _, _) => Container(
          color: c.inputBg,
          child: Icon(Icons.fastfood, color: c.textTertiary, size: 28),
        ),
      );
    }
    return Container(
      color: SColors.primary.withValues(alpha: 0.08),
      child: Icon(Icons.fastfood, color: SColors.primary, size: height * 0.4),
    );
  }
}

/// Simple cart item model.
class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  double get totalPrice => price * quantity;
}

/// Global cart data holder to pass between screens.
class CartDataHolder {
  static Map<String, CartItem> cart = {};
  static String merchantId = '';
  static String merchantName = '';

  static void clear() {
    cart.clear();
    merchantId = '';
    merchantName = '';
  }
}
