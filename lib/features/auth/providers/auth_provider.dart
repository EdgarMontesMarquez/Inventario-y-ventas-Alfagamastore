import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../shared/providers/settings_provider.dart';

class AuthStateData {
  final bool isAuthenticated;
  final String email;
  final String fullName;
  final String userRole; // 'super_admin' | 'admin' | 'empleado'

  const AuthStateData({
    required this.isAuthenticated,
    required this.email,
    required this.fullName,
    required this.userRole,
  });

  bool get isSuperAdmin => userRole == 'super_admin' || userRole == 'admin';
  bool get isAdmin => isSuperAdmin;
  bool get isEmpleado => userRole == 'empleado' || userRole == 'cajero';
}

class AuthNotifier extends Notifier<AuthStateData> {
  @override
  AuthStateData build() {
    final client = Supabase.instance.client;

    final subscription = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        final nameMeta = session.user.userMetadata?['full_name'] as String?;
        _loadUserProfile(session.user.id, session.user.email ?? '', nameMeta);
      } else {
        state = const AuthStateData(
          isAuthenticated: false,
          email: '',
          fullName: '',
          userRole: '',
        );
      }
    });

    ref.onDispose(() {
      subscription.cancel();
    });

    final currentSession = client.auth.currentSession;
    if (currentSession != null) {
      final email = currentSession.user.email ?? '';
      final nameMeta = (currentSession.user.userMetadata?['full_name'] as String?) ??
          (email.contains('@') ? email.split('@')[0] : 'Usuario');
      final roleMeta = (currentSession.user.userMetadata?['role'] as String?) ?? 'empleado';
      _loadUserProfile(currentSession.user.id, email, nameMeta);
      return AuthStateData(
        isAuthenticated: true,
        email: email,
        fullName: nameMeta,
        userRole: roleMeta,
      );
    }

    return const AuthStateData(
      isAuthenticated: false,
      email: '',
      fullName: '',
      userRole: '',
    );
  }

  Future<void> _loadUserProfile(String userId, String email, [String? fallbackName]) async {
    String fetchedRole = 'empleado';
    String fetchedName = fallbackName ?? (email.contains('@') ? email.split('@')[0] : 'Usuario');
    try {
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('full_name, role')
          .eq('id', userId)
          .maybeSingle();

      if (profileRes != null) {
        if (profileRes['role'] != null) {
          fetchedRole = profileRes['role'].toString();
        }
        if (profileRes['full_name'] != null && profileRes['full_name'].toString().trim().isNotEmpty) {
          fetchedName = profileRes['full_name'].toString();
        }
      }
    } catch (_) {}

    state = AuthStateData(
      isAuthenticated: true,
      email: email,
      fullName: fetchedName,
      userRole: fetchedRole,
    );
    PushNotificationService().syncDeviceToken(userId);
    ref.read(settingsProvider.notifier).loadSettings();
  }

  /// Inicia sesión exclusivamente con Supabase Auth (Backend Online)
  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty) {
      return 'Por favor ingresa tu correo electrónico.';
    }
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'El formato del correo electrónico no es válido (ej: usuario@alfagamastore.com).';
    }
    if (cleanPassword.isEmpty) {
      return 'Por favor ingresa tu contraseña.';
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: cleanEmail,
        password: password, // Mantener contraseña original por si incluye caracteres especiales
      );

      if (res.user != null) {
        final emailStr = res.user!.email ?? cleanEmail;
        final nameMeta = (res.user!.userMetadata?['full_name'] as String?) ??
            (emailStr.contains('@') ? emailStr.split('@')[0] : 'Usuario');
        final roleMeta = (res.user!.userMetadata?['role'] as String?) ?? 'empleado';
        state = AuthStateData(
          isAuthenticated: true,
          email: emailStr,
          fullName: nameMeta,
          userRole: roleMeta,
        );
        _loadUserProfile(res.user!.id, emailStr, nameMeta);
        return null; // Éxito
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final code = e.code?.toLowerCase() ?? '';

      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        return 'Credenciales incorrectas:\n'
            '• Verifica que el correo esté bien escrito ($cleanEmail).\n'
            '• Revisa mayúsculas y minúsculas en tu contraseña.\n'
            '• Si es un usuario nuevo, asegúrate de haber confirmado el enlace enviado a tu correo.';
      }
      if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
        return 'Correo no confirmado: Esta cuenta requiere verificación previa.\n\n'
            'Revisa tu bandeja de entrada (o carpeta de spam) de "$cleanEmail" y haz clic en el enlace para activar tu cuenta.';
      }
      if (code == 'over_request_rate_limit' || e.statusCode == '429' || msg.contains('rate limit')) {
        return 'Demasiados intentos de acceso: Por seguridad del sistema, espera 60 segundos antes de volver a intentar.';
      }
      if (code == 'user_not_found' || msg.contains('user not found')) {
        return 'Usuario no encontrado: No existe una cuenta registrada con el correo "$cleanEmail".\n\n'
            'Verifica el correo o solicita a tu administrador que cree tu usuario en el sistema.';
      }
      if (msg.contains('user banned') || msg.contains('disabled')) {
        return 'Acceso denegado: Esta cuenta ha sido suspendida o deshabilitada.';
      }
      return 'Error de acceso (${e.code ?? 'auth'}): ${e.message}';
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('timeout') ||
          errStr.contains('network') ||
          errStr.contains('connection')) {
        return 'Sin conexión al servidor: No se pudo conectar a Supabase.\n\nVerifica tu conexión a internet (WiFi o datos móviles).';
      }
      return 'Error de conexión con Supabase Auth: ${e.toString()}';
    }

    return 'Correo o contraseña incorrectos. Verifica tus datos de acceso.';
  }

  /// Cierra la sesión activa en Supabase Auth y destruye el token en disco
  Future<void> logout() async {
    state = const AuthStateData(
      isAuthenticated: false,
      email: '',
      fullName: '',
      userRole: '',
    );
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthStateData>(() {
  return AuthNotifier();
});
