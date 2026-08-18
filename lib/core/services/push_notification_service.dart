import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Notificación push en segundo plano recibida: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Solicitar permisos en iOS y Android 13+
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Permiso de notificaciones otorgado: ${settings.authorizationStatus}');

      // Manejar mensajes cuando la app está abierta en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Notificación recibida en primer plano: ${message.notification?.title}');
        if (message.notification != null) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.notification?.title ?? 'Notificación Alfa Gama Store',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.notification?.body ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0D1A33),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'VER',
                textColor: const Color(0xFF0066FF),
                onPressed: () => _handleNotificationClick(message),
              ),
            ),
          );
        }
      });

      // Manejar cuando el usuario toca la notificación estando en segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message);
      });

      // Manejar cuando la app se abrió desde cero (Terminated) al tocar una notificación
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }

      // Escuchar cambios de token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _updateTokenInSupabase(newToken);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error al inicializar Firebase Push Notifications: $e');
    }
  }

  /// Sincroniza el FCM Token del dispositivo con el perfil del usuario en Supabase
  Future<void> syncDeviceToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM Token obtenido: $token');
        await _updateTokenInSupabase(token, userId);
      }
    } catch (e) {
      debugPrint('Error al obtener/sincronizar FCM token: $e');
    }
  }

  Future<void> _updateTokenInSupabase(String token, [String? userId]) async {
    try {
      final client = Supabase.instance.client;
      final targetUserId = userId ?? client.auth.currentUser?.id;
      if (targetUserId == null) return;

      // 1. Guardar en profiles
      await client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', targetUserId);

      // 2. Opcional: Registrar en tabla de tokens de dispositivos si existe
      try {
        await client.from('user_device_tokens').upsert({
          'user_id': targetUserId,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'fcm_token');
      } catch (_) {}

      debugPrint('Token FCM sincronizado exitosamente en Supabase para el usuario: $targetUserId');
    } catch (e) {
      debugPrint('Error al guardar token FCM en Supabase: $e');
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    final route = message.data['route'] as String? ?? '/collection-center';
    debugPrint('Abriendo ruta desde notificación push: $route');

    // Navegar directamente a la ruta indicada en el payload
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      routerProvider; // Asegurar provider
      final router = rootNavigatorKey.currentState;
      if (router != null) {
        // Redirigir a la pantalla
        Future.delayed(const Duration(milliseconds: 300), () {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) {
            routerProvider;
          }
        });
      }
    }
  }
}
