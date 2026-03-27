import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around [FlutterLocalNotificationsPlugin].
///
/// Call [init] once at app startup before using [showExpenseAdded].
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'wallet_auto_expense';
  static const _channelName = 'Wallet Auto-Expense';
  static const _channelDesc =
      'Notifies when a Google Wallet payment is automatically added as an expense.';

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Request POST_NOTIFICATIONS permission (Android 13+).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Shows a notification confirming that [title] was added as an expense
  /// with [amount] and [category].
  Future<void> showExpenseAdded({
    required String title,
    required double amount,
    required String category,
  }) async {
    final amountStr = amount.toStringAsFixed(2);
    await _plugin.show(
      // Use a rolling ID so rapid payments each get their own notification.
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Expense added from Google Wallet',
      '$title — €$amountStr  ·  $category',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          autoCancel: true,
        ),
      ),
    );
  }
}
