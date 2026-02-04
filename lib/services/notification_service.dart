import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'proximity_alerts',
    'Proximity Alerts',
    description: 'Alerts when you are near your destination',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _monitorChannel =
      AndroidNotificationChannel(
        'monitoring_status',
        'Monitoring Status',
        description: 'Shows active monitoring status and remaining distance',
        importance: Importance.low,
      );

  static const int _monitoringId = 1002;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // Android: create channel
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_monitorChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationService initialized');
    }
  }

  Future<void> showProximityAlert({
    required String title,
    required String body,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(1001, title, body, details);
  }

  Future<void> showMonitoringStatus({
    required String destinationName,
    required String remainingText,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      _monitorChannel.id,
      _monitorChannel.name,
      channelDescription: _monitorChannel.description,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      _monitoringId,
      'Destination: $destinationName',
      remainingText,
      details,
    );
  }

  Future<void> cancelMonitoringStatus() async {
    await init();
    await _plugin.cancel(_monitoringId);
  }
}
