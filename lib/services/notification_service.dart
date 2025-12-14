import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/job.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;
  
  /// Initialize the notification service
  static Future<void> init() async {
    if (_initialized) return;
    
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // macOS initialization settings
    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _initialized = true;
  }
  
  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // Could navigate to records screen or open the file
    // For now, just log it
  }
  
  /// Request notification permissions (Android 13+)
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    return true;
  }
  
  /// Show notification for job completion
  static Future<void> showJobCompletedNotification(Job job) async {
    if (!_initialized) await init();
    
    final String title;
    final String body;
    
    switch (job.type) {
      case JobType.compress:
        title = '✅ Compression Complete';
        if (job.savingsPercent != null && job.savingsPercent! > 0) {
          body = '${job.filename} - Saved ${job.savingsPercent!.toStringAsFixed(1)}%';
        } else {
          body = '${job.filename} compressed successfully';
        }
        break;
      case JobType.cut:
        title = '✂️ Cut Complete';
        body = '${job.filename} trimmed successfully';
        break;
      case JobType.merge:
        title = '🔗 Merge Complete';
        body = 'Videos merged successfully';
        break;
      case JobType.extractAudio:
        title = '🎵 Audio Extracted';
        body = 'Audio extracted from ${job.filename}';
        break;
      case JobType.audioOnVideo:
        title = '🎬 Audio Added';
        body = 'Audio added to ${job.filename}';
        break;
      case JobType.photosToVideo:
        title = '🎞️ Slideshow Created';
        body = 'Your slideshow is ready';
        break;
      case JobType.addWatermark:
        title = '💧 Watermark Added';
        body = 'Watermark added to ${job.filename}';
        break;
    }
    
    await _showNotification(
      id: job.id.hashCode,
      title: title,
      body: body,
      payload: job.outputPath,
    );
  }
  
  /// Show notification for job failure
  static Future<void> showJobFailedNotification(Job job) async {
    if (!_initialized) await init();
    
    final title = '❌ ${job.typeDisplayName} Failed';
    final body = job.error ?? 'An error occurred processing ${job.filename}';
    
    await _showNotification(
      id: job.id.hashCode,
      title: title,
      body: body,
      isError: true,
    );
  }
  
  /// Internal method to show a notification
  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isError = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'vixel_jobs',
      'Job Notifications',
      channelDescription: 'Notifications for video processing jobs',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: isError ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
    
    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  /// Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
  
  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

