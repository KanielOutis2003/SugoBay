import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets.dart';

class PahapitTabView extends StatefulWidget {
  const PahapitTabView({super.key});

  @override
  PahapitTabViewState createState() => PahapitTabViewState();
}

class PahapitTabViewState extends State<PahapitTabView> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> refresh() async {
    await _loadRequests();
  }

  Future<void> _loadRequests() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      setState(() {
        _error = 'Not logged in';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SupabaseService.pahapitRequests()
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      final data = (response as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load requests: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBody(),
        // FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/pahapit/new');
              // Refresh on return
              _loadRequests();
            },
            backgroundColor: AppColors.teal,
            icon: const Icon(Icons.add, color: AppColors.white),
            label: const Text('New Request',
                style: TextStyle(color: AppColors.white)),
          ),
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
            Text(_error!, style: AppTextStyles.body),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SugoBayButton(text: 'Retry', onPressed: _loadRequests),
            ),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return const EmptyState(
        icon: Icons.delivery_dining,
        title: 'No Pahapit requests yet',
        subtitle: 'Tap + to create your first errand request',
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.cardBg,
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final req = _requests[index];
          return _PahapitCard(
            request: req,
            onTap: () async {
              await context.push('/pahapit/track/${req['id']}');
              _loadRequests();
            },
          );
        },
      ),
    );
  }
}

class _PahapitCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  const _PahapitCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final storeName = request['store_name'] ?? 'Unknown Store';
    final description = request['items_description'] ?? '';
    final status = request['status'] ?? 'pending';
    final budget = (request['budget_limit'] ?? 0).toDouble();

    return SugoBayCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  storeName,
                  style: AppTextStyles.subheading.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  size: 14, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(
                'Budget: \u20B1${budget.toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.gold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
