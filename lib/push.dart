import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';

/// Clave global para mostrar avisos desde cualquier lugar.
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Notificaciones push con Firebase Cloud Messaging.
///
/// Traccar envía el aviso a los "notificationTokens" del usuario. Con la app
/// cerrada o en segundo plano, Android lo muestra solo; con la app abierta se
/// muestra como aviso dentro de la app.
class Push {
  static bool _ready = false;
  static String? token;
  static StreamSubscription<String>? _refreshSub;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: kFirebaseApiKey,
          appId: kFirebaseAppId,
          messagingSenderId: kFirebaseSenderId,
          projectId: kFirebaseProjectId,
        ),
      );
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text([n.title, n.body]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join('\n')),
            duration: const Duration(seconds: 6),
          ));
      });
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static bool get available => _ready;

  /// Pide permiso (Android 13+) y devuelve si quedó autorizado.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final s = await FirebaseMessaging.instance.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<bool> permissionGranted() async {
    if (!_ready) return false;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Registra este celular en el usuario de Traccar.
  static Future<bool> register() async {
    if (!_ready) return false;
    try {
      final granted = await requestPermission();
      if (!granted) return false;
      token = await FirebaseMessaging.instance.getToken();
      final t = token;
      if (t == null) return false;
      await api.setPushToken(t, register: true);
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((nt) async {
        final old = token;
        token = nt;
        try {
          if (old != null) await api.setPushToken(old, register: false);
          await api.setPushToken(nt, register: true);
        } catch (_) {}
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quita este celular del usuario (al cerrar sesión).
  static Future<void> unregister() async {
    final t = token ?? (_ready ? await FirebaseMessaging.instance.getToken() : null);
    if (t == null) return;
    try {
      await api.setPushToken(t, register: false);
    } catch (_) {}
  }

  static bool get registered => token != null && api.hasPushToken(token!);
}
