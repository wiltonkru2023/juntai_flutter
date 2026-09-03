import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  final firebaseReady = await FirebaseService.initialize();

  if (firebaseReady) {
    await NotificationService.instance.initialize();
  }

  runApp(
    const ProviderScope(
      child: JuntaiApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback(
    (_) {
      NotificationService.instance.flushPendingNavigation();
    },
  );
}
