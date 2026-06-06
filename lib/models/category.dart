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
        color: _colorFromJson(json['color']),
        isDefault: json['is_default'] as bool? ?? false,
      );

  static int _colorFromJson(Object? value) {
    if (value == null) return 0xFF9E9E9E;
    if (value is int) return value;
    if (value is String) {
      var hex = value.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      hex = 'FF$hex';
      return int.parse(hex, radix: 16);
    }
    return 0xFF9E9E9E;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'is_default': isDefault,
      };
}
