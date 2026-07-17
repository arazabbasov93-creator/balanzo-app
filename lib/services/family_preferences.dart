import 'package:shared_preferences/shared_preferences.dart';

class FamilyPreferences {
  static const _sharePersonalBudgetKey = 'share_personal_budget_with_family';

  static Future<bool> sharePersonalBudgetWithFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sharePersonalBudgetKey) ?? false;
  }

  static Future<void> setSharePersonalBudgetWithFamily(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharePersonalBudgetKey, value);
  }
}
