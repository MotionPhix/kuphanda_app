import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A notification the app should show while it is in the foreground.
@immutable
class PushNotification {
  const PushNotification({
    required this.title,
    required this.body,
    this.category,
    this.documentId,
    this.route,
  });

  final String title;
  final String body;
  final String? category;
  final String? documentId;
  final String? route;

  factory PushNotification.fromMessage(RemoteMessage message) {
    final data = message.data;
    return PushNotification(
      title: message.notification?.title ?? data['title'] ?? 'Kuphanda',
      body: message.notification?.body ?? data['body'] ?? '',
      category: data['category'],
      documentId: data['document_id'],
      route: data['route'],
    );
  }
}

/// Firebase Cloud Messaging wiring.
///
/// Push is an enhancement, never a requirement: every failure here is caught so
/// a missing configuration (desktop, a build without google-services.json, a
/// device without Play services) cannot block sign-in or reading.
class PushService {
  PushService({
    required this.onToken,
    this.onForeground,
  });

  /// Called with a fresh FCM registration token so the API can store it
  /// against the signed-in account.
  final Future<void> Function(String token) onToken;

  /// Called when a notification arrives while the app is running.
  final void Function(PushNotification notification)? onForeground;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  bool _started = false;
  bool _available = false;
  String? _lastToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'kuphanda_default',
    'Kuphanda updates',
    description:
        'Class messages, subscription receipts and study reminders from Kuphanda.',
    importance: Importance.high,
  );

  /// FCM is only implemented for the mobile targets we ship.
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isAvailable => _available;

  String? get token => _lastToken;

  Future<void> start() async {
    if (_started || !isSupported) return;
    _started = true;

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Android 13+ needs the runtime notification permission.
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          onForeground?.call(
            PushNotification(
              title: '',
              body: '',
              route: payload,
            ),
          );
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // FCM registration tokens (not Firebase Installation IDs) are what the
      // API targets with the HTTP v1 	oken field, so the legacy accessor is
      // still the correct one here.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _lastToken = token;
        await onToken(token);
      }

      // ignore: deprecated_member_use
      _refresh = messaging.onTokenRefresh.listen((token) async {
        _lastToken = token;
        try {
          await onToken(token);
        } catch (_) {
          // Retried on the next launch or sync.
        }
      });

      _foreground = FirebaseMessaging.onMessage.listen(_showForeground);
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onForeground?.call(PushNotification.fromMessage(message));
      });

      _available = true;
    } catch (error) {
      // No Firebase config, no Play services, or unsupported platform.
      _available = false;
      debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = PushNotification.fromMessage(message);
    onForeground?.call(notification);

    if (notification.title.isEmpty && notification.body.isEmpty) return;

    try {
      await _local.show(
        id: message.messageId.hashCode & 0x7fffffff,
        title: notification.title.isEmpty ? 'Kuphanda' : notification.title,
        body: notification.body,
        payload: notification.route ?? notification.documentId,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // A failed local banner must not break the in-app state.
    }
  }

  /// Subscribes the device to an audience topic (`all`, `students`, `teachers`,
  /// `form-3`, ...). Topics let the library reach a segment without holding
  /// every device token.
  Future<void> joinTopics(Iterable<String> topics) async {
    if (!_available) return;
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (_) {
        // Best effort; the API also targets tokens directly.
      }
    }
  }

  Future<void> leaveTopics(Iterable<String> topics) async {
    if (!_available) return;
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _refresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _refresh = null;
    _foreground = null;
    _opened = null;
  }
}
