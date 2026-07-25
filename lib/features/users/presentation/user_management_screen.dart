import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../core/design_system/widgets/custom_overlays.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../shared/widgets/error_state.dart';

final userProfilesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('profiles')
      .select()
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res as List);
});

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  void _openCreateUserSheet(BuildContext context, WidgetRef ref) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Crear Nuevo Usuario',
      child: _CreateUserSheet(
        onSuccess: () {
          ref.invalidate(userProfilesProvider);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _openEditRoleSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> userMap) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Cambiar Rol de Usuario',
      child: _EditRoleSheet(
        userMap: userMap,
        onSuccess: () {
          ref.invalidate(userProfilesProvider);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(userProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios & Roles'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateUserSheet(context, ref),
        backgroundColor: ColorTokens.lightBrandPrimary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nuevo Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: profilesAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando usuarios...'),
        error: (err, stack) => ErrorState(
          title: 'Error al cargar usuarios',
          message: err.toString(),
          onRetry: () => ref.invalidate(userProfilesProvider),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados'));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userProfilesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final p = profiles[idx];
                final role = p['role'] ?? 'empleado';
                final isEmpleado = role == 'empleado' || role == 'cajero';
                final roleLabel = isEmpleado ? 'EMPLEADO' : 'ADMINISTRADOR';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ColorTokens.surface,
                    border: Border.all(color: ColorTokens.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isEmpleado ? ColorTokens.secondary.withAlpha(40) : ColorTokens.primary.withAlpha(40),
                        child: Icon(
                          isEmpleado ? Icons.badge_outlined : Icons.admin_panel_settings_outlined,
                          color: isEmpleado ? ColorTokens.secondary : ColorTokens.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['full_name'] ?? 'Usuario',
                              style: FontTokens.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              p['email'] ?? '',
                              style: FontTokens.bodySmall.copyWith(color: ColorTokens.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isEmpleado ? ColorTokens.secondary.withAlpha(30) : ColorTokens.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleLabel,
                              style: FontTokens.label.copyWith(
                                color: isEmpleado ? ColorTokens.secondary : ColorTokens.primary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _openEditRoleSheet(context, ref, p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                              child: Text(
                                'Cambiar rol',
                                style: FontTokens.label.copyWith(color: ColorTokens.secondary, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const _CreateUserSheet({required this.onSuccess});

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'empleado'; // 'empleado' | 'super_admin'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        data: {
          'full_name': _nameCtrl.text.trim(),
          'role': _role,
        },
      );

      if (res.user != null) {
        // Actualizar o asegurar registro en public.profiles
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'email': _emailCtrl.text.trim(),
          'full_name': _nameCtrl.text.trim(),
          'role': _role,
        });

        if (mounted) {
          final registeredEmail = _emailCtrl.text.trim();
          widget.onSuccess();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined, color: ColorTokens.lightBrandPrimary, size: 24),
                  const SizedBox(width: 8),
                  Text('Verificación de Correo', style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'El usuario se ha registrado correctamente.\n\nSe ha enviado un enlace de confirmación al correo "$registeredEmail". El propietario de la cuenta debe verificar su correo para habilitar su acceso al sistema.',
                style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary),
              ),
              actions: [
                CustomButton(
                  text: 'Entendido',
                  isFullWidth: false,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (e.statusCode == '429' || e.message.contains('rate limit') || e.message.contains('429')) {
          msg = 'Supabase limitó las solicitudes (Error 429: Demasiadas solicitudes de correo).\n\nRevisa la consola de Supabase (Authentication -> Rate Limits) o espera unos minutos antes de registrar otro correo.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ColorTokens.statusDanger,
            duration: const Duration(seconds: 6),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar usuario: ${e.toString()}'),
            backgroundColor: ColorTokens.error,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: 'Nombre Completo del Usuario',
            hint: 'Juan Pérez (Empleado)',
            controller: _nameCtrl,
            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Correo Electrónico',
            hint: 'empleado@alfagamastore.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || !v.contains('@') ? 'Ingrese un email válido' : null,
          ),
          const SizedBox(height: 12),
          CustomPasswordInput(
            label: 'Contraseña de Acceso',
            hint: '******',
            controller: _passCtrl,
            validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 14),
          Text('ROL Y PERMISOS', style: FontTokens.label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _role == 'empleado' ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _role = 'empleado'),
                    child: Row(
                      children: [
                        Icon(
                          _role == 'empleado' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _role == 'empleado' ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Empleado', style: TextStyle(color: ColorTokens.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('Ventas y Abonos', style: TextStyle(color: ColorTokens.lightTextSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _role == 'super_admin' ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _role = 'super_admin'),
                    child: Row(
                      children: [
                        Icon(
                          _role == 'super_admin' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _role == 'super_admin' ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Admin', style: TextStyle(color: ColorTokens.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('Control Total', style: TextStyle(color: ColorTokens.lightTextSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Registrar Usuario',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _EditRoleSheet extends StatefulWidget {
  final Map<String, dynamic> userMap;
  final VoidCallback onSuccess;

  const _EditRoleSheet({required this.userMap, required this.onSuccess});

  @override
  State<_EditRoleSheet> createState() => _EditRoleSheetState();
}

class _EditRoleSheetState extends State<_EditRoleSheet> {
  late String _role;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _role = widget.userMap['role'] ?? 'empleado';
    if (_role == 'cajero') _role = 'empleado';
  }

  void _saveRole() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': _role})
          .eq('id', widget.userMap['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rol actualizado exitosamente'),
            backgroundColor: ColorTokens.lightBrandPrimary,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar rol: $e'),
            backgroundColor: ColorTokens.error,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.userMap['full_name'] ?? 'Usuario',
          style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold),
        ),
        Text(
          widget.userMap['email'] ?? '',
          style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
        ),
        const SizedBox(height: 16),
        Text('SELECCIONA EL NUEVO ROL', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _role == 'empleado' ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: () => setState(() => _role = 'empleado'),
            child: Row(
              children: [
                Icon(
                  _role == 'empleado' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _role == 'empleado' ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Empleado', style: TextStyle(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                      Text('Ventas, búsqueda de inventario y abonos. Sin edición ni finanzas.', style: TextStyle(color: ColorTokens.lightTextSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _role == 'super_admin' ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: () => setState(() => _role = 'super_admin'),
            child: Row(
              children: [
                Icon(
                  _role == 'super_admin' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _role == 'super_admin' ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Administrador', style: TextStyle(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                      Text('Control total sobre inventario, reportes, usuarios y caja.', style: TextStyle(color: ColorTokens.lightTextSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        CustomButton(
          text: 'Guardar cambio de rol',
          isLoading: _isSubmitting,
          onPressed: _saveRole,
        ),
      ],
    );
  }
}
