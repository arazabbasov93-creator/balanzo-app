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
