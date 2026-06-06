import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/income.dart';
import 'supabase_access.dart';

class IncomeService {
  static String _monthKey(int month, int year, {String? userId}) {
    final uid = userId ?? SupabaseAccess.currentUserId ?? 'anon';
    return 'income_${uid}_${year}_$month';
  }

  static String _recurringKey({String? userId}) {
    final uid = userId ?? SupabaseAccess.currentUserId ?? 'anon';
    return 'income_recurring_$uid';
  }

  static Future<List<IncomeEntry>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => IncomeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _writeList(String key, List<IncomeEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<IncomeEntry>> fetchRecurring({String? userId}) =>
      _readList(_recurringKey(userId: userId));

  static Future<List<IncomeEntry>> fetchOneTimeForMonth(
    int month,
    int year, {
    String? userId,
  }) =>
      _readList(_monthKey(month, year, userId: userId));

  static Future<List<IncomeEntry>> fetchForMonth(int month, int year,
      {String? userId}) async {
    final recurring = await fetchRecurring(userId: userId);
    final oneTime = await fetchOneTimeForMonth(month, year, userId: userId);
    return [...recurring, ...oneTime];
  }

  static Future<double> totalForMonth(int month, int year, {String? userId}) async {
    final entries = await fetchForMonth(month, year, userId: userId);
    return entries.fold<double>(0.0, (sum, entry) => sum + entry.amount);
  }

  static Future<void> saveRecurring(List<IncomeEntry> entries) async {
    await _writeList(_recurringKey(), entries);
  }

  static Future<void> saveOneTimeForMonth(
    int month,
    int year,
    List<IncomeEntry> entries,
  ) async {
    await _writeList(_monthKey(month, year), entries);
  }

  static Future<void> upsert({
    required int month,
    required int year,
    required String label,
    required double amount,
    required bool recurring,
    String? entryId,
  }) async {
    final id = entryId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final entry = IncomeEntry(
      id: id,
      label: label,
      amount: amount,
      recurring: recurring,
    );

    if (entryId != null) {
      final recurringList = await fetchRecurring();
      final oneTimeList = await fetchOneTimeForMonth(month, year);
      final wasRecurring = recurringList.any((e) => e.id == entryId);
      final wasOneTime = oneTimeList.any((e) => e.id == entryId);
      if (wasRecurring && !recurring) {
        await remove(month: month, year: year, entryId: entryId, recurring: true);
      } else if (wasOneTime && recurring) {
        await remove(month: month, year: year, entryId: entryId, recurring: false);
      }
    }

    if (recurring) {
      final entries = await fetchRecurring();
      final idx = entries.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        entries[idx] = entry;
      } else {
        entries.add(entry);
      }
      await saveRecurring(entries);
    } else {
      final entries = await fetchOneTimeForMonth(month, year);
      final idx = entries.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        entries[idx] = entry;
      } else {
        entries.add(entry);
      }
      await saveOneTimeForMonth(month, year, entries);
    }
  }

  static Future<void> remove({
    required int month,
    required int year,
    required String entryId,
    required bool recurring,
  }) async {
    if (recurring) {
      final entries = await fetchRecurring()
        ..removeWhere((e) => e.id == entryId);
      await saveRecurring(entries);
    } else {
      final entries = await fetchOneTimeForMonth(month, year)
        ..removeWhere((e) => e.id == entryId);
      await saveOneTimeForMonth(month, year, entries);
    }
  }
}
