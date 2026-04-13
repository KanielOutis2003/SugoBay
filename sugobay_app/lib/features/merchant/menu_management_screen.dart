import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../shared/widgets.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  bool _isLoading = true;
  String? _error;
  String _merchantId = '';
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, List<Map<String, dynamic>>> _groupedItems = {};

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
      final merchant = await SupabaseService.merchants()
          .select('id')
          .eq('user_id', SupabaseService.currentUserId!)
          .single();
      _merchantId = merchant['id'];
      await _loadMenuItems();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMenuItems() async {
    final res = await SupabaseService.menuItems()
        .select()
        .eq('merchant_id', _merchantId)
        .order('category')
        .order('name');

    final items = List<Map<String, dynamic>>.from(res);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final category = (item['category'] ?? 'Uncategorized') as String;
      grouped.putIfAbsent(category, () => []).add(item);
    }

    if (mounted) {
      setState(() {
        _menuItems = items;
        _groupedItems = grouped;
      });
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item) async {
    final newVal = !(item['is_available'] == true);
    try {
      await SupabaseService.menuItems()
          .update({'is_available': newVal}).eq('id', item['id']);
      setState(() {
        item['is_available'] = newVal;
      });
      if (mounted) {
        showSugoBaySnackBar(
          context,
          newVal ? '${item['name']} is now available' : '${item['name']} marked unavailable',
        );
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to update: $e', isError: true);
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Delete Item', style: AppTextStyles.subheading),
        content: Text(
          'Are you sure you want to delete "${item['name']}"?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.menuItems().delete().eq('id', item['id']);
      if (mounted) {
        showSugoBaySnackBar(context, '${item['name']} deleted');
        await _loadMenuItems();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to delete: $e', isError: true);
      }
    }
  }

  void _showItemForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuItemFormSheet(
        merchantId: _merchantId,
        existing: existing,
        onSaved: () {
          _loadMenuItems();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final name = item['name'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final imageUrl = item['image_url'] as String?;
    final isAvailable = item['is_available'] == true;

    return GestureDetector(
      onTap: () => _showItemForm(existing: item),
      onLongPress: () => _deleteItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkGrey.withAlpha(128)),
        ),
        child: Row(
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.darkGrey,
                          child: const Icon(Icons.fastfood, color: Colors.white24),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.darkGrey,
                          child: const Icon(Icons.broken_image, color: Colors.white24),
                        ),
                      )
                    : Container(
                        color: AppColors.darkGrey,
                        child: const Icon(Icons.fastfood, color: Colors.white24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u20B1${price.toStringAsFixed(2)}',
                    style: AppTextStyles.body.copyWith(color: AppColors.gold),
                  ),
                ],
              ),
            ),
            // Availability toggle
            Column(
              children: [
                Switch(
                  value: isAvailable,
                  onChanged: (_) => _toggleAvailability(item),
                  activeColor: AppColors.success,
                  inactiveThumbColor: AppColors.coral,
                ),
                Text(
                  isAvailable ? 'Available' : 'Unavailable',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: isAvailable ? AppColors.success : AppColors.coral,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBg,
        appBar: AppBar(
          backgroundColor: AppColors.cardBg,
          title: Text('Menu Management', style: AppTextStyles.subheading),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.coral),
                const SizedBox(height: 16),
                Text('Failed to load menu', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SugoBayButton(text: 'Retry', onPressed: _loadData),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: Text('Menu Management', style: AppTextStyles.subheading),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${_menuItems.length} items',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
      body: _menuItems.isEmpty
          ? EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No Menu Items',
              subtitle: 'Tap + to add your first item',
            )
          : RefreshIndicator(
              onRefresh: _loadMenuItems,
              color: AppColors.teal,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _groupedItems.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: AppTextStyles.subheading.copyWith(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${entry.value.length})',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      ...entry.value.map(_buildItemTile),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemForm(),
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- Bottom sheet form for adding/editing menu items ---

class _MenuItemFormSheet extends StatefulWidget {
  final String merchantId;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _MenuItemFormSheet({
    required this.merchantId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_MenuItemFormSheet> createState() => _MenuItemFormSheetState();
}

class _MenuItemFormSheetState extends State<_MenuItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isSaving = false;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _existingImageUrl;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.existing!['name'] ?? '';
      _descController.text = widget.existing!['description'] ?? '';
      _priceController.text =
          (widget.existing!['price'] ?? '').toString();
      _categoryController.text = widget.existing!['category'] ?? '';
      _existingImageUrl = widget.existing!['image_url'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload image if picked
      if (_pickedImageBytes != null) {
        final ext = _pickedImageName?.split('.').last ?? 'jpg';
        final path =
            '${widget.merchantId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        imageUrl = await SupabaseService.uploadFile(
          bucket: 'menu-images',
          path: path,
          fileBytes: _pickedImageBytes!,
          contentType: 'image/$ext',
        );
      }

      final data = {
        'merchant_id': widget.merchantId,
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'category': _categoryController.text.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      };

      if (isEditing) {
        await SupabaseService.menuItems()
            .update(data)
            .eq('id', widget.existing!['id']);
      } else {
        data['is_available'] = true;
        await SupabaseService.menuItems().insert(data);
      }

      if (mounted) {
        showSugoBaySnackBar(
          context,
          isEditing ? 'Item updated' : 'Item added',
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to save: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Menu Item' : 'Add Menu Item',
                style: AppTextStyles.heading.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 20),

              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.darkGrey),
                  ),
                  child: _pickedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            _pickedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : (_existingImageUrl != null &&
                              _existingImageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: _existingImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_outlined,
                                    size: 40, color: Colors.white38),
                                const SizedBox(height: 8),
                                Text('Tap to add image',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),

              SugoBayTextField(
                label: 'Item Name',
                hint: 'e.g. Chicken Adobo',
                controller: _nameController,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              SugoBayTextField(
                label: 'Description',
                hint: 'Short description of the item',
                controller: _descController,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              SugoBayTextField(
                label: 'Price (\u20B1)',
                hint: '0.00',
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Price is required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              SugoBayTextField(
                label: 'Category',
                hint: 'e.g. Rice Meals, Drinks, Snacks',
                controller: _categoryController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Category is required'
                    : null,
              ),
              const SizedBox(height: 24),

              SugoBayButton(
                text: isEditing ? 'Update Item' : 'Add Item',
                onPressed: _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
