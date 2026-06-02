class Budget {
  final String id;
  final String? familyId;
  final String? userId;
  final String? categoryId;
  final String? categoryName;
  final double amount;
  final int month;
  final int year;
  double spent;

  Budget({
    required this.id,
    this.familyId,
    this.userId,
    this.categoryId,
    this.categoryName,
    required this.amount,
    required this.month,
    required this.year,
    this.spent = 0,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    final cat = json['categories'] as Map<String, dynamic>?;
    return Budget(
      id: json['id'] as String,
      familyId: json['family_id'] as String?,
      userId: json['user_id'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: cat?['name'] as String?,
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
    );
  }

  double get remaining => amount - spent;
  double get usedFraction => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => spent > amount;
}
