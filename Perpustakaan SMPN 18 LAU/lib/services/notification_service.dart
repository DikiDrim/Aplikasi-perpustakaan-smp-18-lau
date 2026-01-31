import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_notification_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final AppNotificationService _appNotificationService =
      AppNotificationService();

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(initSettings);

    // Android 13+ runtime permission
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Menjadwalkan notifikasi jatuh tempo DAN menyimpan ke database
  static Future<void> scheduleDueNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dueAt,
    required String userId,
    String type = 'keterlambatan',
    bool remindAfterDue = false,
    Duration reminderDelay = const Duration(minutes: 5),
    Map<String, dynamic>? data,
  }) async {
    await init();

    // Jadwalkan notifikasi lokal (optional - tetap bisa digunakan untuk reminder)
    final tzTime = tz.TZDateTime.from(dueAt, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'due_channel',
      'Jatuh Tempo',
      channelDescription: 'Notifikasi jatuh tempo peminjaman',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    // Simpan notifikasi ke database inbox
    await _appNotificationService.createNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
    );

    if (remindAfterDue) {
      final reminderTime = tzTime.add(reminderDelay);
      await _plugin.zonedSchedule(
        id + 1,
        '$title - Waktu Habis',
        'Waktu peminjaman sudah habis. Mohon kembalikan buku.',
        reminderTime,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  /// Menampilkan notifikasi pop-up dan menyimpan ke database
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String userId,
    String type = 'info',
    Map<String, dynamic>? data,
    bool showPopup = true,
  }) async {
    await init();

    // Tampilkan pop-up lokal (skip di web karena plugin tidak support)
    if (showPopup && !kIsWeb) {
      const androidDetails = AndroidNotificationDetails(
        'inbox_channel',
        'Inbox Notification',
        channelDescription: 'Notifikasi umum aplikasi',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    }

    // Simpan ke database sebagai inbox
    await _appNotificationService.createNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }

  /// Helper untuk broadcast notifikasi ke semua admin
  static Future<void> showNotificationToAllAdmins({
    required int id,
    required String title,
    required String body,
    String type = 'info',
    Map<String, dynamic>? data,
  }) async {
    await init();

    // Simpan notifikasi untuk semua admin
    await _appNotificationService.createNotificationForAllAdmins(
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }
}
