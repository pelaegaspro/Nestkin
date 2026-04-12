import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

class NotificationRouteData {
  final String householdId;
  final String? taskId;

  const NotificationRouteData({
    required this.householdId,
    this.taskId,
  });

  factory NotificationRouteData.fromMessage(RemoteMessage message) {
    return NotificationRouteData(
      householdId: message.data['householdId'] as String,
      taskId: message.data['taskId'] as String?,
    );
  }
}

class FCMService {
  factory FCMService() => _instance;

  FCMService._internal();

  static final FCMService _instance = FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenSubscription;
  bool _initialized = false;

  Future<void> init({
    required void Function(RemoteMessage message) onForegroundMessage,
    required Future<void> Function(NotificationRouteData route) onNotificationTap,
  }) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _syncCurrentUserToken();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        return;
      }

      await _syncTokenForUser(user.uid);
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || token.isEmpty) {
        return;
      }

      try {
        await _firestoreService.updateFcmToken(uid: user.uid, token: token);
      } catch (error) {
        debugPrint('FCM token refresh sync failed: $error');
      }
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      onForegroundMessage(message);
    });

    _messageOpenSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final route = _routeFromMessage(message);
      if (route == null) {
        return;
      }

      await onNotificationTap(route);
    });

    final initialMessage = await _messaging.getInitialMessage();
    final initialRoute = _routeFromMessage(initialMessage);
    if (initialRoute != null) {
      await onNotificationTap(initialRoute);
    }
  }

  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  Future<void> _syncCurrentUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await _syncTokenForUser(user.uid);
  }

  Future<void> _syncTokenForUser(String uid) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _firestoreService.updateFcmToken(uid: uid, token: token);
    } catch (error) {
      debugPrint('Initial FCM token sync failed: $error');
    }
  }

  NotificationRouteData? _routeFromMessage(RemoteMessage? message) {
    if (message == null) {
      return null;
    }

    final householdId = message.data['householdId'];
    if (householdId is! String || householdId.isEmpty) {
      return null;
    }

    return NotificationRouteData.fromMessage(message);
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _authSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _messageOpenSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _authSubscription = null;
    _foregroundSubscription = null;
    _messageOpenSubscription = null;
    _initialized = false;
  }
}
