import 'package:flutter/material.dart';

final ValueNotifier<String> currentLanguage = ValueNotifier('en');
final ValueNotifier<ThemeMode> currentThemeMode = ValueNotifier(ThemeMode.light);

/// Display name for greeting — warmed from auth/DB before Home loads.
final ValueNotifier<String?> cachedDisplayName = ValueNotifier<String?>(null);

/// Bumped after a receipt is saved or deleted so Home/Receipts refresh.
final ValueNotifier<int> receiptsRevision = ValueNotifier(0);

void notifyReceiptsChanged() => receiptsRevision.value++;
