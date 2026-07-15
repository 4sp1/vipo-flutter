import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notifications = FlutterLocalNotificationsPlugin();

Future<void> initialize() async {
  final initialized = await notifications.initialize(
    settings: const InitializationSettings(
      macOS: DarwinInitializationSettings(),
    ),
  );

  final macosPlugin = notifications
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >();

  if (macosPlugin == null) {
    return;
  }

  await macosPlugin.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

  await notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

Future<void> show({required String title, required String body}) async {
  try {
    await notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (_) {
    // Silently ignore notification errors: notification failures must not
    // affect the user's timer flow.
  }
}