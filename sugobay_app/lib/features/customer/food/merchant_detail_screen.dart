import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
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

  // Cart: key = item id, value = CartItem
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBg,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Text(
          _merchant?['shop_name'] ?? 'Merchant',
          style: AppTextStyles.subheading,
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _cartItemCount > 0 ? _buildCartBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.coral, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.body),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SugoBayButton(text: 'Retry', onPressed: _loadData),
            ),
          ],
        ),
      );
    }

    if (_merchant == null) {
      return const EmptyState(
        icon: Icons.store,
        title: 'Merchant not found',
      );
    }

    return CustomScrollView(
      slivers: [
        // Merchant header
        SliverToBoxAdapter(child: _buildMerchantHeader()),
        // Menu items grouped by category
        ..._buildMenuSections(),
        // Bottom padding for cart bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMerchantHeader() {
    final m = _merchant!;
    final rating = (m['rating'] ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkGrey.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m['shop_name'] ?? '', style: AppTextStyles.heading),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.category, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Text(m['category'] ?? '', style: AppTextStyles.body),
              const SizedBox(width: 16),
              const Icon(Icons.star, size: 14, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1),
                  style: AppTextStyles.body.copyWith(color: AppColors.gold)),
            ],
          ),
          if (m['address'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(m['address'], style: AppTextStyles.caption),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMenuSections() {
    final groups = _groupedItems;
    if (groups.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.restaurant_menu,
            title: 'No menu items available',
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final entry in groups.entries) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            entry.key,
            style: AppTextStyles.subheading.copyWith(color: AppColors.gold),
          ),
        ),
      ));
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = entry.value[index];
            return _buildMenuItem(item);
          },
          childCount: entry.value.length,
        ),
      ));
    }
    return slivers;
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final name = item['name'] ?? '';
    final description = item['description'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final imageUrl = item['image_url'];
    final qty = _cart[id]?.quantity ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkGrey.withAlpha(80)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.darkGrey,
                        child: const Icon(Icons.fastfood,
                            color: Colors.white38, size: 28),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.darkGrey,
                        child: const Icon(Icons.fastfood,
                            color: Colors.white38, size: 28),
                      ),
                    )
                  : Container(
                      color: AppColors.darkGrey,
                      child: const Icon(Icons.fastfood,
                          color: Colors.white38, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.body.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                )),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '\u20B1${price.toStringAsFixed(2)}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Add/quantity controls
          if (qty == 0)
            IconButton(
              onPressed: () => _addToCart(item),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: AppColors.white, size: 18),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: () => _removeFromCart(id),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$qty',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.white, fontSize: 16)),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () => _addToCart(item),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCartBar() {
    return GestureDetector(
      onTap: () {
        // Pass cart data and merchant info to cart screen via CartDataHolder
        CartDataHolder.cart = Map.from(_cart);
        CartDataHolder.merchantId = widget.merchantId;
        CartDataHolder.merchantName = _merchant?['shop_name'] ?? 'Merchant';
        context.push('/cart');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_cartItemCount',
                style: AppTextStyles.button,
              ),
            ),
            const SizedBox(width: 12),
            const Text('View Cart', style: AppTextStyles.button),
            const Spacer(),
            Text(
              '\u20B1${_cartTotal.toStringAsFixed(2)}',
              style: AppTextStyles.button,
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: AppColors.teal, size: 16),
      ),
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
/// In production, consider using Riverpod or another state management solution.
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
