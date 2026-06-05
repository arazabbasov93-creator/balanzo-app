import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _historyKey = 'notification_history';
  static const _permissionAskedKey = 'notification_permission_asked';

  static const _channel = AndroidNotificationChannel(
    'balanzo_notifications',
    'Balanzo Alerts',
    description: 'Budget and spending alerts',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<bool> hasPermissionBeenAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionAskedKey) ?? false;
  }

  static Future<void> requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionAskedKey, true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String type = 'info',
  }) async {
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
    await _saveToHistory(title: title, body: body, type: type);
  }

  static Future<void> sendRestockReminder(String itemName) async {
    await _show(
      id: 100,
      title: 'Restock Reminder',
      body: 'You usually buy "$itemName" around now.',
      type: 'restock',
    );
  }

  // VAT TRACKER: Hidden — requires government ƏDV
  // API integration. Do not delete.
  // Re-enable when API is available.
  // static Future<void> sendVatAlert(double vatAmount) async {
  //   await _show(
  //     id: 101,
  //     title: 'Unclaimed VAT Alert',
  //     body:
  //         'You have ${vatAmount.toStringAsFixed(2)} AZN in unclaimed VAT this month.',
  //     type: 'vat',
  //   );
  // }

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

  // --- History persistence (shown in NotificationsScreen) ---

  static Future<void> _saveToHistory({
    required String title,
    required String body,
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final entry = jsonEncode({
      'title': title,
      'body': body,
      'type': type,
      'ts': DateTime.now().toIso8601String(),
    });
    raw.insert(0, entry);
    if (raw.length > 50) raw.removeRange(50, raw.length);
    await prefs.setStringList(_historyKey, raw);
  }

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
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

  /// Call after first receipt scan to ask permission (T103).
  static Future<void> requestIfNotAsked() async {
    if (!await hasPermissionBeenAsked()) {
      await requestPermission();
    }
  }
}
