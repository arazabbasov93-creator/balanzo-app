import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../utils/product_name_normalizer.dart';

class NotificationService {
  /// iOS native plugin can SIGKILL the process during initialize(); keep off iOS.
  static bool get _nativeEnabled => !Platform.isIOS;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _historyKey = 'notification_history';
  static const _permissionAskedKey = 'notification_permission_asked';

  static const _channel = AndroidNotificationChannel(
    'balanzo_notifications',
    'Balanzo Alerts',
    description: 'Budget and spending alerts',
    importance: Importance.high,
  );

  /// Lazy init — never call during app bootstrap (native iOS plugin can crash/kill).
  static bool _initialized = false;
  static bool _initFailed = false;

  static Future<void> init() async {
    if (!_nativeEnabled || _initialized || _initFailed) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _initialized = true;
    } catch (e, st) {
      _initFailed = true;
      debugPrint('[NotificationService] init failed: $e\n$st');
    }
  }

  static Future<void> ensureInitialized() async {
    if (_initialized || _initFailed) return;
    await init();
  }

  static Future<bool> hasPermissionBeenAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionAskedKey) ?? false;
  }

  static Future<void> requestPermission() async {
    if (!_nativeEnabled) return;
    await ensureInitialized();
    if (!_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionAskedKey, true);
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e, st) {
      debugPrint('[NotificationService] requestPermission failed: $e\n$st');
    }
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String type = 'info',
    String? itemKey,
    String? cycleKey,
  }) async {
    if (!_nativeEnabled) {
      await _saveToHistory(
        title: title,
        body: body,
        type: type,
        itemKey: itemKey,
        cycleKey: cycleKey,
      );
      return;
    }
    await ensureInitialized();
    if (!_initialized) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'balanzo_notifications',
          'Balanzo Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
      await _saveToHistory(
        title: title,
        body: body,
        type: type,
        itemKey: itemKey,
        cycleKey: cycleKey,
      );
    } catch (e, st) {
      debugPrint('[NotificationService] show failed: $e\n$st');
    }
  }

  static Future<void> sendRestockReminder({
    required String itemName,
    required DateTime nextDue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final itemKey = ProductNameNormalizer.normalize(itemName);
    final dueKey = nextDue.toIso8601String().substring(0, 10);
    final sentKey = 'restock_reminder_sent_${itemKey}_$dueKey';
    if (prefs.getBool(sentKey) == true) return;

    final lang = currentLanguage.value;
    final title = AppStrings.get('notif_restock_title', lang);
    final body = AppStrings.notifRestockBody(itemName, lang);

    await _show(
      id: 100,
      title: title,
      body: body,
      type: 'restock',
      itemKey: itemKey,
      cycleKey: dueKey,
    );
    await prefs.setBool(sentKey, true);
  }

  /// Clears restock reminder dedupe for an item (e.g. after marking bought).
  static Future<void> clearRestockReminderSent(String itemName) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'restock_reminder_sent_${ProductNameNormalizer.normalize(itemName)}_';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static Future<void> sendMonthlySummary({
    required double total,
    required int receiptCount,
  }) async {
    await _show(
      id: 102,
      title: 'Monthly Summary',
      body:
          'Last month you spent ${total.toStringAsFixed(2)} AZN across $receiptCount receipts.',
      type: 'summary',
    );
  }

  static Future<void> sendPriceAnomaly(String itemName, double pctAbove) async {
    await _show(
      id: 103,
      title: 'Price Alert',
      body:
          '"$itemName" is ${pctAbove.toStringAsFixed(0)}% more expensive than your last purchase.',
      type: 'price',
    );
  }

  static Future<void> _saveToHistory({
    required String title,
    required String body,
    required String type,
    String? itemKey,
    String? cycleKey,
  }) async {
    try {
      if (type == 'restock' && itemKey != null && cycleKey != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getStringList(_historyKey) ?? [];
        for (final e in raw) {
          final map = Map<String, dynamic>.from(jsonDecode(e) as Map);
          if (map['type'] == 'restock' &&
              map['item_key'] == itemKey &&
              map['cycle_key'] == cycleKey) {
            return;
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      final entry = jsonEncode({
        'title': title,
        'body': body,
        'type': type,
        'ts': DateTime.now().toIso8601String(),
        'read': false,
        if (itemKey != null) 'item_key': itemKey,
        if (cycleKey != null) 'cycle_key': cycleKey,
      });
      raw.insert(0, entry);
      if (raw.length > 50) raw.removeRange(50, raw.length);
      await prefs.setStringList(_historyKey, raw);
    } catch (e, st) {
      debugPrint('[NotificationService] save history failed: $e\n$st');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    return raw
        .asMap()
        .entries
        .map((e) {
          final map = Map<String, dynamic>.from(jsonDecode(e.value) as Map);
          map.putIfAbsent('read', () => false);
          map['_index'] = e.key;
          return map;
        })
        .toList();
  }

  static Future<int> unreadCount() async {
    final items = await fetchHistory();
    return items.where((e) => e['read'] != true).length;
  }

  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final updated = raw.map((e) {
      final map = Map<String, dynamic>.from(jsonDecode(e) as Map);
      map['read'] = true;
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList(_historyKey, updated);
  }

  static Future<void> markAsUnread(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    if (index < 0 || index >= raw.length) return;
    final map = Map<String, dynamic>.from(jsonDecode(raw[index]) as Map);
    map['read'] = false;
    raw[index] = jsonEncode(map);
    await prefs.setStringList(_historyKey, raw);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  static Future<void> sendFamilyBudgetAlert({
    required String memberName,
    required double overspend,
  }) async {
    await _show(
      id: 104,
      title: 'Family budget alert',
      body:
          '$memberName is over their budget by ${overspend.toStringAsFixed(2)} AZN this month.',
      type: 'budget',
    );
  }

  static Future<void> requestIfNotAsked() async {
    if (!await hasPermissionBeenAsked()) {
      await requestPermission();
    }
  }
}
