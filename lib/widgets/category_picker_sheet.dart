import 'package:flutter/material.dart';
import '../models/category.dart';
import '../utils/icon_mapper.dart';

Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Category> categories,
  String? selectedId,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => CategoryPickerSheet(
      categories: categories,
      selectedId: selectedId,
    ),
  );
}

class CategoryPickerSheet extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.clear, color: Colors.grey),
          title: const Text('No category'),
          onTap: () => Navigator.of(context).pop(null),
        ),
        ...categories.map(
          (cat) => ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Color(cat.color).withValues(alpha: 0.15),
              child: Icon(iconForName(cat.icon), color: Color(cat.color), size: 16),
            ),
            title: Text(cat.name),
            trailing: cat.id == selectedId
                ? const Icon(Icons.check, color: Color(0xFF1B5E20))
                : null,
            onTap: () => Navigator.of(context).pop(cat.id),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
