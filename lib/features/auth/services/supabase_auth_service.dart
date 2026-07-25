import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient client;

  SupabaseAuthService(this.client);

  /// Inicia sesión con correo y contraseña en Supabase Auth
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cierra la sesión activa en el dispositivo
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Obtiene el usuario autenticado actualmente en Supabase
  User? get currentUser => client.auth.currentUser;

  /// Obtiene la sesión activa en Supabase
  Session? get currentSession => client.auth.currentSession;

  /// Stream reactivo de cambios en la autenticación (Login, Logout, Token Refresh)
  Stream<AuthState> get onAuthStateChange => client.auth.onAuthStateChange;
}
