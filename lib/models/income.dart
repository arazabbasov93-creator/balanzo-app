class IncomeEntry {
  final String id;
  final String label;
  final double amount;
  final bool recurring;

  const IncomeEntry({
    required this.id,
    required this.label,
    required this.amount,
    this.recurring = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'recurring': recurring,
      };

  factory IncomeEntry.fromJson(Map<String, dynamic> json) => IncomeEntry(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        recurring: json['recurring'] as bool? ?? false,
      );

  IncomeEntry copyWith({
    String? id,
    String? label,
    double? amount,
    bool? recurring,
  }) =>
      IncomeEntry(
        id: id ?? this.id,
        label: label ?? this.label,
        amount: amount ?? this.amount,
        recurring: recurring ?? this.recurring,
      );
}
