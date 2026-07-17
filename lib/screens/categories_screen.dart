import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/category_display.dart';
import '../utils/icon_mapper.dart';
import '../config/app_colors.dart';

const _formIconOptions = <String>[
  'shopping_cart',
  'restaurant',
  'local_pharmacy',
  'directions_car',
  'home',
  'school',
  'pets',
  'fitness_center',
  'local_cafe',
  'flight',
  'checkroom',
  'cleaning_services',
  'phone_android',
  'child_care',
  'wine_bar',
  'hardware',
  'savings',
  'celebration',
  'local_grocery_store',
  'electrical_services',
  'build',
  'local_hospital',
  'sports_soccer',
  'movie',
];

const _formColors = <int>[
  0xFF1B5E20,
  0xFF1565C0,
  0xFFB71C1C,
  0xFFE65100,
  0xFF4A148C,
  0xFF006064,
  0xFF37474F,
  0xFF558B2F,
  0xFF4E342E,
  0xFF00695C,
];

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _future = CategoryService.fetchForSettings();
  }

  void _refresh() {
    setState(() => _future = CategoryService.fetchForSettings());
  }

  Future<void> _openForm({Category? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CategoryFormSheet(category: existing),
    );
    if (saved == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(AppStrings.get('categories', lang)),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cats = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            itemBuilder: (_, i) {
              final cat = cats[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(cat.color).withValues(alpha: 0.15),
                    child: Icon(iconForName(cat.icon), color: Color(cat.color), size: 20),
                  ),
                  title: Text(displayCategoryName(cat, lang)),
                  subtitle: cat.isDefault
                      ? Text(
                          AppStrings.get('category_default', lang),
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _openForm(existing: cat),
                      ),
                      if (!cat.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () async {
                            await CategoryService.delete(cat.id);
                            await CategoryService.refreshCache();
                            _refresh();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final Category? category;

  const _CategoryFormSheet({this.category});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  late int _color;
  bool _saving = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _icon = widget.category?.icon ?? _formIconOptions.first;
    _color = widget.category?.color ?? _formColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final lang = currentLanguage.value;
    try {
      if (_isEdit) {
        await CategoryService.update(widget.category!.id, name, _icon, _color);
      } else {
        await CategoryService.create(name, _icon, _color);
      }
      await CategoryService.refreshCache();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get('error_generic', lang)}: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit
                  ? AppStrings.get('edit_category', lang)
                  : AppStrings.get('new_category', lang),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.get('category_name_label', lang),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('pick_icon', lang),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _formIconOptions.length,
                itemBuilder: (_, i) {
                  final name = _formIconOptions[i];
                  final selected = name == _icon;
                  return InkWell(
                    onTap: () => setState(() => _icon = name),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryGreenDark.withValues(alpha: 0.15)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryGreenDark
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Icon(iconForName(name), size: 22),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('pick_color', lang),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _formColors.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black87 : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreenDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_isEdit ? AppStrings.get('save', lang) : AppStrings.get('add_category', lang)),
            ),
          ],
        ),
      ),
    );
  }
}
