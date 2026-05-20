import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notifications = FlutterLocalNotificationsPlugin();

Future<void> initialize() async {
  final initialized = await notifications.initialize(
    settings: const InitializationSettings(
      macOS: DarwinInitializationSettings(),
    ),
  );
  print('Notification initialized: $initialized');

  final macosPlugin = notifications
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >();

  if (macosPlugin == null) {
    print('ERROR: macOS notification plugin not available');
    return;
  }

  final granted = await macosPlugin.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
  print('macOS notification permissions granted: $granted');

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
    print('Notification shown: $title - $body');
  } catch (e) {
    print('ERROR showing notification: $e');
  }
}
