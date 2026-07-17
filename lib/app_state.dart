import 'package:flutter/material.dart';

/// True after Supabase.initialize() succeeds in bootstrap.
bool supabaseReady = false;

/// Notifies [AuthGateScreen] when bootstrap finishes (avoids stuck offline UI).
final ValueNotifier<bool> supabaseReadyNotifier = ValueNotifier(false);

final ValueNotifier<String> currentLanguage = ValueNotifier('en');
final ValueNotifier<ThemeMode> currentThemeMode = ValueNotifier(ThemeMode.light);

/// Display name for greeting — warmed from auth/DB before Home loads.
final ValueNotifier<String?> cachedDisplayName = ValueNotifier<String?>(null);

/// Bumped after a receipt is saved or deleted so Home/Receipts refresh.
final ValueNotifier<int> receiptsRevision = ValueNotifier(0);

/// Selected month/year for Home and Family spend views.
class HomePeriod {
  final int month;
  final int year;

  const HomePeriod({required this.month, required this.year});
}

final ValueNotifier<HomePeriod> homePeriod = ValueNotifier(
  HomePeriod(month: DateTime.now().month, year: DateTime.now().year),
);

void notifyReceiptsChanged() => receiptsRevision.value++;

/// Root navigator for deep-link navigation after cold start.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
