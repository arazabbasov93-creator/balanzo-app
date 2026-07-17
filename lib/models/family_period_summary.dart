/// Family budget totals for a calendar month — shared by Profile and Home family tab.
class FamilyPeriodSummary {
  final String familyId;
  final String familyName;
  final int month;
  final int year;
  final double availableBudget;
  final bool hasBudget;
  final double spent;

  const FamilyPeriodSummary({
    required this.familyId,
    required this.familyName,
    required this.month,
    required this.year,
    required this.availableBudget,
    required this.hasBudget,
    required this.spent,
  });

  double get remaining => availableBudget - spent;
}
