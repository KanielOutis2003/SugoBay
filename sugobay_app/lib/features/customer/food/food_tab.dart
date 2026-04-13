import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets.dart';

class FoodTabView extends StatefulWidget {
  const FoodTabView({super.key});

  @override
  FoodTabViewState createState() => FoodTabViewState();
}

class FoodTabViewState extends State<FoodTabView> {
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _filteredMerchants = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'Restaurant',
    'Carenderia',
    'Fast Food',
    'BBQ',
    'Bakery',
    'Cafe',
  ];

  @override
  void initState() {
    super.initState();
    _loadMerchants();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load merchants: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMerchants = _merchants.where((m) {
        final matchesCategory = _selectedCategory == 'All' ||
            (m['category'] ?? '').toString().toLowerCase() ==
                _selectedCategory.toLowerCase();
        final matchesSearch = query.isEmpty ||
            (m['shop_name'] ?? '').toString().toLowerCase().contains(query);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Search restaurants...',
              hintStyle: AppTextStyles.caption,
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.darkGrey, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
          ),
        ),

        // Category chips
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedCategory = cat);
                  _applyFilters();
                },
                selectedColor: AppColors.teal,
                backgroundColor: AppColors.cardBg,
                side: BorderSide(
                  color: isSelected ? AppColors.teal : AppColors.darkGrey,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Merchant list
        Expanded(
          child: _buildBody(),
        ),
      ],
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
            Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SugoBayButton(
              text: 'Retry',
              onPressed: _loadMerchants,
            ),
          ],
        ),
      );
    }

    if (_filteredMerchants.isEmpty) {
      return const EmptyState(
        icon: Icons.store_mall_directory,
        title: 'No merchants found',
        subtitle: 'Try a different search or category',
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.cardBg,
      onRefresh: _loadMerchants,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _filteredMerchants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final merchant = _filteredMerchants[index];
          return _MerchantCard(
            merchant: merchant,
            onTap: () => context.push('/merchant/${merchant['id']}'),
          );
        },
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  final Map<String, dynamic> merchant;
  final VoidCallback onTap;

  const _MerchantCard({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = merchant['shop_name'] ?? 'Unknown';
    final category = merchant['category'] ?? '';
    final rating = (merchant['rating'] ?? 0).toDouble();
    final isOpen = merchant['is_open'] == true;

    return SugoBayCard(
      onTap: onTap,
      child: Row(
        children: [
          // Merchant icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.darkGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: AppColors.teal, size: 28),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.subheading.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      category,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.star, color: AppColors.gold, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Open/closed badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOpen
                  ? AppColors.success.withAlpha(38)
                  : AppColors.error.withAlpha(38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOpen ? AppColors.success : AppColors.error,
              ),
            ),
            child: Text(
              isOpen ? 'Open' : 'Closed',
              style: TextStyle(
                color: isOpen ? AppColors.success : AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
