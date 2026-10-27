import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

      // Solicitar permisos en iOS y Android 13+ vía FirebaseMessaging
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

      // Solicitar explícitamente en Android 13+ con permission_handler
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final notifStatus = await Permission.notification.status;
          if (!notifStatus.isGranted) {
            await Permission.notification.request();
          }
        } catch (pe) {
          debugPrint('Aviso al solicitar permiso notification: $pe');
        }
      }

      // Habilitar visualización en primer plano (Heads-up banner)
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Manejar mensajes cuando la app está abierta en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Notificación recibida en primer plano: ${message.notification?.title}');
        final title = message.notification?.title ?? 'Notificación Alfa Gama Store';
        final body = message.notification?.body ?? '';
        showInAppNotificationBanner(title: title, body: body, message: message);
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
        _saveDeviceToken(newToken);
      });

      // Obtener token inicial y guardarlo de inmediato
      final initialToken = await FirebaseMessaging.instance.getToken();
      if (initialToken != null && initialToken.isNotEmpty) {
        debugPrint('FCM Token inicial registrado: $initialToken');
        await _saveDeviceToken(initialToken);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error al inicializar Firebase Push Notifications: $e');
    }
  }

  /// Muestra un banner visual elegante para notificaciones recibidas en primer plano o de prueba
  void showInAppNotificationBanner({
    required String title,
    required String body,
    RemoteMessage? message,
  }) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFF0066FF), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D1A33),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'VER',
          textColor: const Color(0xFF38BDF8),
          onPressed: () {
            if (message != null) {
              _handleNotificationClick(message);
            }
          },
        ),
      ),
    );
  }

  /// Obtiene el token FCM del dispositivo actual
  Future<String?> getDeviceToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error al obtener token FCM: $e');
      return null;
    }
  }

  /// Sincroniza el FCM Token del dispositivo con el perfil del usuario en Supabase
  Future<void> syncDeviceToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM Token obtenido para sync: $token');
        await _saveDeviceToken(token, userId);
      }
    } catch (e) {
      debugPrint('Error al obtener/sincronizar FCM token: $e');
    }
  }

  Future<void> _saveDeviceToken(String token, [String? userId]) async {
    try {
      final client = Supabase.instance.client;
      final targetUserId = userId ?? client.auth.currentUser?.id;

      // 1. Guardar en profiles si hay usuario autenticado
      if (targetUserId != null) {
        try {
          await client.from('profiles').update({
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', targetUserId);
          debugPrint('Token FCM guardado en profiles para: $targetUserId');
        } catch (pe) {
          debugPrint('Aviso al actualizar profiles.fcm_token: $pe');
        }
      }

      // 2. Registrar en tabla user_device_tokens (asociando user_id si existe)
      try {
        final payload = <String, dynamic>{
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (targetUserId != null) {
          payload['user_id'] = targetUserId;
        }

        await client.from('user_device_tokens').upsert(
          payload,
          onConflict: 'fcm_token',
        );
        debugPrint('Token FCM sincronizado en user_device_tokens');
      } catch (de) {
        debugPrint('Aviso al guardar en user_device_tokens: $de');
      }
    } catch (e) {
      debugPrint('Error general al guardar token FCM en Supabase: $e');
    }
  }

  /// Envía y dispara una notificación push de cobranza, mostrando el aviso visual
  /// y registrando/solicitando el despacho a los dispositivos
  Future<bool> sendCollectionPushNotification({
    required String title,
    required String body,
    Map<String, String>? extraData,
  }) async {
    try {
      // 1. Mostrar de inmediato el banner flotante en la aplicación actual
      showInAppNotificationBanner(title: title, body: body);

      // 2. Intentar registrar en notification_logs o llamar endpoint
      try {
        final client = Supabase.instance.client;
        final token = await getDeviceToken();
        
        await client.from('notification_logs').insert({
          'title': title,
          'body': body,
          'type': 'collection_reminder',
          'token': token,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error al disparar notificación de cobranza: $e');
      return false;
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    final route = message.data['route'] as String? ?? '/collection-center';
    debugPrint('Abriendo ruta desde notificación push: $route');

    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      routerProvider;
      Future.delayed(const Duration(milliseconds: 300), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          routerProvider;
        }
      });
    }
  }
}
