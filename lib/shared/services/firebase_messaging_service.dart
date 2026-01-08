import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  factory FirebaseMessagingService() {
    return _instance;
  }

  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      // Request permission
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('[FCM] Notification permission granted: ${settings.authorizationStatus}');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      print('[FCM] Device token: $token');
    } catch (e) {
      print('[FCM] Error initializing Firebase Messaging: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('[FCM] Foreground message received: ${message.messageId}');
    print('[FCM] Message data: ${message.data}');
    print('[FCM] Message title: ${message.notification?.title}');
    print('[FCM] Message body: ${message.notification?.body}');

    // Show local notification
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('[FCM] Notification tapped: ${message.messageId}');
    // Handle navigation based on message data
    _handleNotificationNavigation(message);
  }

  void _handleNotificationResponse(
      NotificationResponse notificationResponse) {
    print(
        '[FCM] Local notification tapped: ${notificationResponse.payload}');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    try {
      await _localNotificationsPlugin.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    } catch (e) {
      print('[FCM] Error showing notification: $e');
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    // Handle navigation based on message data
    // This can be extended based on your app's needs
    final data = message.data;

    if (data.containsKey('type')) {
      final type = data['type'];
      print('[FCM] Notification type: $type');
      // Implement navigation logic here
      // Example: if (type == 'task') navigate to task details
    }
  }

  /// Enable push notifications
  Future<void> enablePushNotifications() async {
    try {
      print('[FCM] Enabling push notifications...');
      await _firebaseMessaging.subscribeToTopic('all_users');
      print('[FCM] Subscribed to all_users topic');
    } catch (e) {
      print('[FCM] Error enabling push notifications: $e');
      rethrow;
    }
  }

  /// Disable push notifications
  Future<void> disablePushNotifications() async {
    try {
      print('[FCM] Disabling push notifications...');
      await _firebaseMessaging.unsubscribeFromTopic('all_users');
      print('[FCM] Unsubscribed from all_users topic');
    } catch (e) {
      print('[FCM] Error disabling push notifications: $e');
      rethrow;
    }
  }

  /// Get device FCM token
  Future<String?> getDeviceToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('[FCM] Error getting device token: $e');
      return null;
    }
  }

  /// Subscribe to a specific topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      print('[FCM] Error subscribing to topic: $e');
      rethrow;
    }
  }

  /// Unsubscribe from a specific topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      print('[FCM] Error unsubscribing from topic: $e');
      rethrow;
    }
  }
}

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('[FCM] Background message received: ${message.messageId}');
  print('[FCM] Message data: ${message.data}');
  print('[FCM] Message title: ${message.notification?.title}');
  print('[FCM] Message body: ${message.notification?.body}');
  
  // You can add background task handling here if needed
}
