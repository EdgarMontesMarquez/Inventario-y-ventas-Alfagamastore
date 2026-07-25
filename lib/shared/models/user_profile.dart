class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'super_admin' | 'cajero'

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  bool get isSuperAdmin => role == 'super_admin';
  bool get isCajero => role == 'cajero';
}
