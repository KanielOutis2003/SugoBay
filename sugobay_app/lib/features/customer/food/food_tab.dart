import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets.dart';
import '../../../shared/announcements_banner.dart';

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
    final c = context.sc;

    return Column(
      children: [
        const AnnouncementsBanner(),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.plusJakartaSans(color: c.textPrimary, fontSize: 14),
            cursorColor: SColors.primary,
            decoration: InputDecoration(
              hintText: 'Search restaurants...',
              hintStyle:
                  GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary),
              prefixIcon:
                  Icon(Icons.search, color: c.textTertiary, size: 20),
              filled: true,
              fillColor: c.inputBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: SColors.primary, width: 2),
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
                selectedColor: SColors.primary,
                backgroundColor: c.cardBg,
                side: BorderSide(
                  color: isSelected ? SColors.primary : c.border,
                ),
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: isSelected ? Colors.white : c.textSecondary,
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
        Expanded(child: _buildBody(c)),
      ],
    );
  }

  Widget _buildBody(SugoColors c) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(count: 5, itemHeight: 88),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: SColors.coral, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textSecondary),
                textAlign: TextAlign.center),
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
      color: SColors.primary,
      backgroundColor: c.cardBg,
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
    final c = context.sc;
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
              color: SColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront,
                color: SColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          // Info
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
                Row(
                  children: [
                    Text(category,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: c.textTertiary)),
                    const SizedBox(width: 10),
                    const Icon(Icons.star, color: SColors.gold, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: SColors.gold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Open/closed badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOpen
                  ? SColors.success.withAlpha(38)
                  : SColors.error.withAlpha(38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOpen ? SColors.success : SColors.error,
              ),
            ),
            child: Text(
              isOpen ? 'Open' : 'Closed',
              style: GoogleFonts.plusJakartaSans(
                color: isOpen ? SColors.success : SColors.error,
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
