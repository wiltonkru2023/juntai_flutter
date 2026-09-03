import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'juntai_high_importance';
  static const _channelName = 'Notificações do Juntaí';
  static const _channelDescription =
      'Mensagens, solicitações e atualizações de atividades.';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  String? _registeredUid;
  String? _registeredToken;
  String? _pendingRoute;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const ios = DarwinInitializationSettings();

    await _local.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: ios,
      ),
      onDidReceiveNotificationResponse: (
        NotificationResponse response,
      ) {
        final payload = response.payload?.trim();

        if (payload != null && payload.isNotEmpty) {
          _openRoute(payload);
        }
      },
    );

    final launchDetails = await _local.getNotificationAppLaunchDetails();

    final launchPayload = launchDetails?.notificationResponse?.payload?.trim();

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _pendingRoute = launchPayload;
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        _openRouteFromMessage(message);
      },
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
    );

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
          _handleAuthChanged,
        );

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _pendingRoute = _routeFor(initialMessage);
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await _registerCurrentToken(user.uid);
    }
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> syncTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _registerCurrentToken(user.uid);
  }

  Future<void> unregisterCurrentDevice() async {
    await _removeRegisteredToken();
  }

  Future<void> clearDeliveredNotifications() async {
    await _local.cancelAll();
  }

  void flushPendingNavigation() {
    final route = _pendingRoute;
    if (route == null || route.isEmpty) return;

    _pendingRoute = null;
    _openRoute(route);
  }

  Future<void> _handleAuthChanged(User? user) async {
    if (_registeredUid != null && _registeredUid != user?.uid) {
      await _removeRegisteredToken();
    }

    if (user == null) return;

    await _registerCurrentToken(user.uid);
  }

  Future<void> _handleTokenRefresh(
    String token,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_registeredUid != null &&
        _registeredToken != null &&
        _registeredToken != token) {
      await _deleteTokenDocument(
        _registeredUid!,
        _registeredToken!,
      );
    }

    await _saveToken(user.uid, token);
  }

  Future<void> _registerCurrentToken(
    String uid,
  ) async {
    try {
      final settings = await requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await _saveToken(uid, token);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Falha ao registrar token FCM: $error',
        );
      }
    }
  }

  Future<void> _saveToken(
    String uid,
    String token,
  ) async {
    final docId = _tokenDocumentId(token);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(docId)
        .set(
      {
        'token': token,
        'platform': Platform.operatingSystem,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    _registeredUid = uid;
    _registeredToken = token;
  }

  Future<void> _removeRegisteredToken() async {
    final uid = _registeredUid;
    final token = _registeredToken;

    _registeredUid = null;
    _registeredToken = null;

    if (uid == null || token == null) {
      return;
    }

    try {
      await _deleteTokenDocument(uid, token);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Falha ao remover token FCM: $error',
        );
      }
    }
  }

  Future<void> _deleteTokenDocument(
    String uid,
    String token,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(_tokenDocumentId(token))
        .delete();
  }

  String _tokenDocumentId(String token) {
    return base64Url.encode(utf8.encode(token)).replaceAll('=', '');
  }

  Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;

    final title = notification?.title ?? message.data['title']?.toString();

    final body = notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final unread = await _unreadCount();

    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      number: unread,
      icon: '@mipmap/ic_launcher',
    );

    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: unread,
    );

    await _local.show(
      id: message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: ios,
      ),
      payload: _routeFor(message),
    );
  }

  Future<int> _unreadCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (_) {
      return 1;
    }
  }

  String _routeFor(RemoteMessage message) {
    final explicitRoute = message.data['route']?.toString();
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    final activityId = message.data['activityId']?.toString();
    final actorId = message.data['actorId']?.toString();
    final type = message.data['type']?.toString();

    if ((type == 'private_message' || type == 'new_direct_message') &&
        actorId != null &&
        actorId.isNotEmpty) {
      return '/message/$actorId';
    }

    if (activityId == null || activityId.isEmpty) {
      return '/notifications';
    }

    if (type == 'new_message') {
      return '/chat/$activityId';
    }

    return '/activity/$activityId';
  }

  void _openRouteFromMessage(
    RemoteMessage message,
  ) {
    _openRoute(_routeFor(message));
  }

  void _openRoute(String route) {
    final context = notificationNavigatorKey.currentContext;

    if (context == null) {
      _pendingRoute = route;
      return;
    }

    try {
      GoRouter.of(context).go(route);
    } catch (_) {
      _pendingRoute = route;
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
