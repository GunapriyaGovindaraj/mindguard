import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<void> sendWarning(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mindguard_warnings',
        'MindGuard Warnings',
        channelDescription: 'Mental health early warning notifications',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFF00D4AA),
      ),
    );
    await _plugin.show(0, title, body, details);
  }

  static Future<void> sendEncouragement(String message) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mindguard_encourage',
        'MindGuard Encouragement',
        channelDescription: 'Daily wellness encouragement',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(1, '💚 MindGuard', message, details);
  }

  static Future<void> sendALICheckIn() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mindguard_ali',
        'ALI Check-in',
        channelDescription: 'ALI wellness check-in',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      2,
      '💬 ALI wants to check in',
      'Hey! How are you feeling today? I\'m here to listen 🌿',
      details,
    );
  }
}