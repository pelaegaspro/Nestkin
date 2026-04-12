import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'screens/household_screen.dart';
import 'screens/home_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  runApp(const NestkinApp());
}

class NestkinApp extends StatefulWidget {
  const NestkinApp({super.key});

  @override
  State<NestkinApp> createState() => _NestkinAppState();
}

class _NestkinAppState extends State<NestkinApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    await _fcmService.init(
      onForegroundMessage: _showForegroundMessage,
      onNotificationTap: _openNotificationRoute,
    );
  }

  void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    final route = _routeFromMessage(message);
    final title = notification.title ?? 'New notification';
    final body = notification.body;

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(body == null || body.isEmpty ? title : '$title\n$body'),
        behavior: SnackBarBehavior.floating,
        action: route == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () {
                  _openNotificationRoute(route);
                },
              ),
      ),
    );
  }

  NotificationRouteData? _routeFromMessage(RemoteMessage message) {
    final householdId = message.data['householdId'];
    if (householdId is! String || householdId.isEmpty) {
      return null;
    }

    final taskId = message.data['taskId'];
    return NotificationRouteData(
      householdId: householdId,
      taskId: taskId is String && taskId.isNotEmpty ? taskId : null,
    );
  }

  Future<void> _openNotificationRoute(NotificationRouteData route) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final household = await FirestoreService().getHousehold(route.householdId);
    if (household == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('That household is no longer available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          householdId: route.householdId,
          initialTaskId: route.taskId,
        ),
      ),
      (existingRoute) => existingRoute.isFirst,
    );
  }

  @override
  void dispose() {
    _fcmService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nestkin',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5C68)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const HouseholdScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}
