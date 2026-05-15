import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
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
          newVal
              ? '${item['name']} is now available'
              : '${item['name']} marked unavailable',
        );
      }
    } catch (e) {
      if (mounted) {
        showSugoBaySnackBar(context, 'Failed to update: $e', isError: true);
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final c = context.sc;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Delete Item',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                )),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to delete "${item['name']}"?',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SugoBayButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.pop(ctx, false),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SugoBayButton(
                    text: 'Delete',
                    onPressed: () => Navigator.pop(ctx, true),
                    color: SColors.coral,
                  ),
                ),
              ],
            ),
            SizedBox(
                height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
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

  Widget _buildItemTile(Map<String, dynamic> item, SugoColors c) {
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
          color: c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
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
                          color: c.inputBg,
                          child: Icon(Icons.fastfood,
                              color: c.textTertiary),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: c.inputBg,
                          child: Icon(Icons.broken_image,
                              color: c.textTertiary),
                        ),
                      )
                    : Container(
                        color: c.inputBg,
                        child: Icon(Icons.fastfood,
                            color: c.textTertiary),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u20B1${price.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: SColors.gold),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isAvailable,
                  onChanged: (_) => _toggleAvailability(item),
                  activeThumbColor: SColors.success,
                  inactiveThumbColor: SColors.coral,
                ),
                Text(
                  isAvailable ? 'Available' : 'Unavailable',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: isAvailable ? SColors.success : SColors.coral,
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
    final c = context.sc;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(
            child: CircularProgressIndicator(color: SColors.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.cardBg,
          title: Text('Menu Management',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              )),
          iconTheme: IconThemeData(color: c.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56,
                    color: SColors.coral),
                const SizedBox(height: 16),
                Text('Failed to load menu',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    )),
                const SizedBox(height: 8),
                Text(_error!,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SugoBayButton(text: 'Retry', onPressed: _loadData),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.cardBg,
        title: Text('Menu Management',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${_menuItems.length} items',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: c.textTertiary),
              ),
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
              color: SColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _groupedItems.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 10, top: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: SColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${entry.value.length})',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: c.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      ...entry.value
                          .map((item) => _buildItemTile(item, c)),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemForm(),
        backgroundColor: SColors.primary,
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
  List<String> _existingCategories = [];
  String? _merchantCategory;

  static const List<String> _defaultCategories = [
    'Chicken & Platters',
    'Burgers',
    'Rice Meals',
    'Pasta & Noodles',
    'Fries & Sides',
    'Drinks & Beverages',
    'Desserts',
    'Snacks',
    'Breakfast',
    'Value Meals',
    'Family Meals',
    'Coffee',
    'Milk Tea',
    'Pizza',
    'Sandwiches',
  ];

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
    _loadCategoryInfo();
  }

  Future<void> _loadCategoryInfo() async {
    try {
      final items = await SupabaseService.menuItems()
          .select('category')
          .eq('merchant_id', widget.merchantId);
      final cats = <String>{};
      for (final item in items) {
        final c = item['category'] as String?;
        if (c != null && c.isNotEmpty) cats.add(c);
      }

      final merchant = await SupabaseService.merchants()
          .select('category')
          .eq('id', widget.merchantId)
          .single();

      if (mounted) {
        setState(() {
          _existingCategories = cats.toList()..sort();
          _merchantCategory = merchant['category'] as String?;
        });
      }
    } catch (_) {}
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
    final file =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
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
    final c = context.sc;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Menu Item' : 'Add Menu Item',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
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
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons
                                        .add_photo_alternate_outlined,
                                    size: 40,
                                    color: c.textTertiary),
                                const SizedBox(height: 8),
                                Text('Tap to add image',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: c.textTertiary)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),

              SugoBayTextField(
                label: 'Item Name',
                hint: 'e.g. Chicken Adobo',
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
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
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Price is required';
                  }
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Category dropdown with autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category',
                      style: GoogleFonts.plusJakartaSans(
                        color: SColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(
                        text: _categoryController.text),
                    optionsBuilder: (textEditingValue) {
                      final query =
                          textEditingValue.text.toLowerCase();
                      final allCats = <String>{
                        ..._existingCategories,
                        ..._defaultCategories
                      };
                      if (query.isEmpty) return allCats;
                      return allCats.where(
                          (cat) => cat.toLowerCase().contains(query));
                    },
                    onSelected: (value) {
                      _categoryController.text = value;
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onEditingComplete) {
                      if (controller.text.isEmpty &&
                          _categoryController.text.isNotEmpty) {
                        controller.text = _categoryController.text;
                      }
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        onChanged: (v) =>
                            _categoryController.text = v,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: c.textPrimary),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Chicken & Platters, Drinks',
                          hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: c.textTertiary),
                          filled: true,
                          fillColor: c.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: SColors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          suffixIcon: Icon(Icons.arrow_drop_down,
                              color: c.textTertiary),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Category is required'
                                : null,
                      );
                    },
                    optionsViewBuilder:
                        (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: c.cardBg,
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 4),
                              itemCount: options.length,
                              itemBuilder: (_, i) {
                                final opt = options.elementAt(i);
                                final isExisting =
                                    _existingCategories
                                        .contains(opt);
                                return ListTile(
                                  dense: true,
                                  title: Text(opt,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          color: c.textPrimary)),
                                  trailing: isExisting
                                      ? Text('existing',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color:
                                                SColors.primary,
                                          ))
                                      : null,
                                  onTap: () => onSelected(opt),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
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
