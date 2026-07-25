import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    ref.read(settingsProvider.notifier).loadSettings();
  }

  /// Inicia sesión exclusivamente con Supabase Auth (Backend Online)
  Future<String?> login(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.user != null) {
        final emailStr = res.user!.email ?? email;
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
      return e.message;
    } catch (e) {
      return 'Error de conexión con Supabase Auth: ${e.toString()}';
    }

    return 'Correo o contraseña incorrectos';
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
