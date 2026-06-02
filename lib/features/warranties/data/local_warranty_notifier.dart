import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'warranty_notifier.dart';

/// Implementacija [WarrantyNotifier] preko flutter_local_notifications.
///
/// Lokalne notifikacije — rade offline, bez servera.
class LocalWarrantyNotifier implements WarrantyNotifier {
  LocalWarrantyNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'warranty_reminders';
  static const _channelName = 'Podsetnici za garancije';

  bool _tzReady = false;

  /// Inicijalizacija (pozvati jednom iz main).
  static Future<LocalWarrantyNotifier> create() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    return LocalWarrantyNotifier(plugin);
  }

  void _ensureTimezone() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    _tzReady = true;
  }

  @override
  Future<void> scheduleReminders({
    required int warrantyId,
    required String title,
    required DateTime expiryDate,
    DateTime? now,
  }) async {
    _ensureTimezone();
    // Najpre očisti stare termine za ovu garanciju (idempotentno).
    await cancelReminders(warrantyId);

    for (final r in ReminderSchedule.compute(expiryDate, now: now)) {
      final id = warrantyNotificationId(warrantyId, r.daysBefore);
      await _plugin.zonedSchedule(
        id: id,
        title: 'Garancija ističe za ${r.daysBefore} dana',
        body: title,
        scheduledDate: tz.TZDateTime.from(r.fireAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Podseti pre isteka garancije/saobraznosti',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelReminders(int warrantyId) async {
    for (final offset in const [30, 7]) {
      await _plugin.cancel(id: warrantyNotificationId(warrantyId, offset));
    }
  }
}
