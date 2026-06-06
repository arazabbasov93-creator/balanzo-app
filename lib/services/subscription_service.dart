import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_access.dart';

enum SubscriptionTier { free, aiPremium, familyPlan }

class SubscriptionService {
  static const double aiPremiumMonthly = 0.99;
  static const double aiPremiumAnnual = 9.99;
  static const double familyPlanMonthly = 1.99;
  static const double familyPlanAnnual = 19.99;

  static const _tierKey = 'subscription_tier';
  static SupabaseClient get _supabase => SupabaseAccess.client;

  // T129: Check subscription status on launch from Supabase
  static Future<SubscriptionTier> fetchTier() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return SubscriptionTier.free;
      final data = await _supabase
          .from('users')
          .select('subscription_tier')
          .eq('id', userId)
          .maybeSingle();
      final tierStr = data?['subscription_tier'] as String?;
      final tier = _parseTier(tierStr);
      // Cache locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierKey, tierStr ?? 'free');
      return tier;
    } catch (_) {
      return _cachedTier();
    }
  }

  static Future<SubscriptionTier> _cachedTier() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseTier(prefs.getString(_tierKey));
  }

  static SubscriptionTier _parseTier(String? tier) {
    switch (tier) {
      case 'ai_premium':
        return SubscriptionTier.aiPremium;
      case 'family_plan':
        return SubscriptionTier.familyPlan;
      default:
        return SubscriptionTier.free;
    }
  }

  static Future<bool> isPremium() async {
    final tier = await fetchTier();
    return tier != SubscriptionTier.free;
  }

  static Future<bool> hasAiAccess() async {
    final tier = await fetchTier();
    return tier == SubscriptionTier.aiPremium || tier == SubscriptionTier.familyPlan;
  }

  // T130: AI feature gate
  static Future<void> requireAiAccess() async {
    if (!await hasAiAccess()) {
      throw const SubscriptionException('AI features require AI Premium or Family Plan.');
    }
  }

  static Future<void> upgradeTo(SubscriptionTier tier) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    String tierStr;
    switch (tier) {
      case SubscriptionTier.aiPremium:
        tierStr = 'ai_premium';
      case SubscriptionTier.familyPlan:
        tierStr = 'family_plan';
      default:
        tierStr = 'free';
    }
    await _supabase.from('users').update({'subscription_tier': tierStr}).eq('id', userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tierStr);
  }

  static Future<AiAccessResult> checkAiAccess() async {
    try {
      final tier = await fetchTier();
      if (tier != SubscriptionTier.free) {
        return AiAccessResult(allowed: true, tier: tier, dataWindowDays: 90);
      }

      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return AiAccessResult(allowed: false, tier: tier);

      final userRow = await _supabase
          .from('users')
          .select('created_at')
          .eq('id', uid)
          .single();

      final createdAt = DateTime.parse(userRow['created_at'] as String);
      final monthsActive = DateTime.now().difference(createdAt).inDays ~/ 30;
      final dataWindowDays = monthsActive >= 6 ? 30 : 7;

      final weekStart = _weekStart();
      final row = await _supabase
          .from('ai_usage')
          .select('question_count')
          .eq('user_id', uid)
          .eq('week_start', weekStart.toIso8601String().substring(0, 10))
          .maybeSingle();

      final count = (row?['question_count'] as int?) ?? 0;
      final allowed = count < 1;

      return AiAccessResult(
        allowed: allowed,
        tier: tier,
        dataWindowDays: dataWindowDays,
        questionsUsed: count,
        questionsLimit: 1,
        isLoyalUser: monthsActive >= 6,
      );
    } catch (_) {
      return const AiAccessResult(allowed: false, tier: SubscriptionTier.free);
    }
  }

  static DateTime _weekStart() {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - 1) % 7;
    return DateTime(now.year, now.month, now.day - daysFromMonday);
  }
}

class SubscriptionException implements Exception {
  final String message;
  const SubscriptionException(this.message);
  @override
  String toString() => message;
}

class AiAccessResult {
  final bool allowed;
  final SubscriptionTier tier;
  final int dataWindowDays;
  final int questionsUsed;
  final int questionsLimit;
  final bool isLoyalUser;

  const AiAccessResult({
    required this.allowed,
    required this.tier,
    this.dataWindowDays = 7,
    this.questionsUsed = 0,
    this.questionsLimit = 1,
    this.isLoyalUser = false,
  });
}
