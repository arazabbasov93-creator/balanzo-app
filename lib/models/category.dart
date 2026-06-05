class Category {
  final String id;
  final String name;
  final String icon;
  final int color;
  final bool isDefault;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? 'category',
        color: json['color'] as int? ?? 0xFF9E9E9E,
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'is_default': isDefault,
      };
}

// Seed categories shown when user has none yet
const defaultCategories = [
  {'name': 'Grocery', 'icon': 'local_grocery_store', 'color': 0xFF4CAF50},
  {'name': 'Restaurant', 'icon': 'restaurant', 'color': 0xFFFF9800},
  {'name': 'Tobacco', 'icon': 'smoking_rooms', 'color': 0xFF795548},
  {'name': 'Transport', 'icon': 'directions_car', 'color': 0xFF2196F3},
  {'name': 'Health', 'icon': 'local_pharmacy', 'color': 0xFFF44336},
  {'name': 'Clothing', 'icon': 'checkroom', 'color': 0xFF9C27B0},
  {'name': 'Utilities', 'icon': 'bolt', 'color': 0xFF607D8B},
  {'name': 'Education', 'icon': 'school', 'color': 0xFF00BCD4},
  {'name': 'Other', 'icon': 'category', 'color': 0xFF9E9E9E},
];
