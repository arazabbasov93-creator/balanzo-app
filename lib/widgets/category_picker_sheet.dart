import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/category_display.dart';
import '../utils/icon_mapper.dart';
import '../config/app_colors.dart';

const _categoryColors = <int>[
  0xFF4CAF50,
  0xFF2196F3,
  0xFFFF9800,
  0xFFE91E63,
  0xFF9C27B0,
  0xFF00BCD4,
  0xFF795548,
  0xFF607D8B,
  0xFFFF5722,
  0xFF3F51B5,
  0xFF009688,
  0xFF9E9E9E,
];

const _iconOptions = <String>[
  'category',
  'local_grocery_store',
  'restaurant',
  'directions_car',
  'local_pharmacy',
  'checkroom',
  'bolt',
  'child_care',
  'fitness_center',
  'pets',
  'flight',
  'home',
  'local_cafe',
  'school',
  'medical_services',
  'receipt_long',
];

Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  List<Category>? categories,
  String? selectedId,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => CategoryPickerSheet(
      categories: categories,
      selectedId: selectedId,
    ),
  );
}

class CategoryPickerSheet extends StatefulWidget {
  final List<Category>? categories;
  final String? selectedId;

  const CategoryPickerSheet({
    super.key,
    this.categories,
    this.selectedId,
  });

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _categories = widget.categories ?? CategoryService.cached;
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    if (_categories.isEmpty) {
      CategoryService.fetchAll().then((cats) {
        if (mounted) setState(() => _categories = cats);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Category> get _filtered {
    if (_query.isEmpty) return _categories;
    return _categories
        .where((c) => c.name.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    var selectedIcon = 'category';
    var selectedColor = _categoryColors.first;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('New Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                const Text('Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _iconOptions.map((icon) {
                    final selected = icon == selectedIcon;
                    return InkWell(
                      onTap: () => setLocal(() => selectedIcon = icon),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(selectedColor).withValues(alpha: 0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? Color(selectedColor) : Colors.grey.shade300,
                          ),
                        ),
                        child: Icon(iconForName(icon), size: 20, color: Color(selectedColor)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryColors.map((color) {
                    final selected = color == selectedColor;
                    return GestureDetector(
                      onTap: () => setLocal(() => selectedColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.black87, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final cat = await CategoryService.create(name, selectedIcon, selectedColor);
    if (cat != null && mounted) {
      setState(() {
        _categories = CategoryService.cached;
      });
      Navigator.of(context).pop(cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered = _filtered;
    final maxH = MediaQuery.of(context).size.height * 0.65;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search categories…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.grey),
              title: const Text('No category'),
              onTap: () => Navigator.of(context).pop(null),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final cat = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(cat.color).withValues(alpha: 0.15),
                      child: Icon(iconForName(cat.icon), color: Color(cat.color), size: 16),
                    ),
                    title: Text(
                      displayCategoryName(cat, currentLanguage.value),
                    ),
                    trailing: cat.id == widget.selectedId
                        ? Icon(Icons.check, color: AppColors.primaryGreen(brightness))
                        : null,
                    onTap: () => Navigator.of(context).pop(cat.id),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: OutlinedButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add new category'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen(brightness),
                  side: BorderSide(color: AppColors.primaryGreen(brightness)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
