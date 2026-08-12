import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeNameCtrl;
  late final TextEditingController _nitCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _footerCtrl;
  late bool _soundOnScan;
  late bool _autoPrintReceipt;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _storeNameCtrl = TextEditingController(text: settings.storeName);
    _nitCtrl = TextEditingController(text: settings.nit);
    _phoneCtrl = TextEditingController(text: settings.phone);
    _addressCtrl = TextEditingController(text: settings.address);
    _footerCtrl = TextEditingController(text: settings.receiptFooter);
    _soundOnScan = settings.soundOnScan;
    _autoPrintReceipt = settings.autoPrintReceipt;
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _nitCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  void _saveSettings() async {
    final isAdmin = ref.read(authProvider).isAdmin;
    if (_isSaving) return;
    if (isAdmin && _formKey.currentState != null && !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final current = ref.read(settingsProvider);
      final updated = current.copyWith(
        storeName: isAdmin ? _storeNameCtrl.text.trim() : current.storeName,
        nit: isAdmin ? _nitCtrl.text.trim() : current.nit,
        phone: isAdmin ? _phoneCtrl.text.trim() : current.phone,
        address: isAdmin ? _addressCtrl.text.trim() : current.address,
        receiptFooter: isAdmin ? _footerCtrl.text.trim() : current.receiptFooter,
        soundOnScan: _soundOnScan,
        autoPrintReceipt: _autoPrintReceipt,
      );

      await ref.read(settingsProvider.notifier).updateSettings(updated);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada exitosamente'),
            backgroundColor: ColorTokens.lightBrandPrimary,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ColorTokens.lightSurfacePrimary,
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: BorderShadowTokens.shadow3DCard,
                ),
                child: Row(
                  children: [
                    const AppLogo(size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.fullName.isNotEmpty
                                ? authState.fullName
                                : (authState.email.isNotEmpty
                                    ? authState.email.split('@')[0].toUpperCase()
                                    : 'Usuario AlfaGama'),
                            style: FontTokens.h3.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(authState.email.isNotEmpty ? authState.email : 'admin@alfagamastore.com', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ColorTokens.lightBrandPrimary.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              authState.userRole.isNotEmpty
                                  ? authState.userRole.replaceAll('_', ' ').toUpperCase()
                                  : 'SUPER ADMIN',
                              style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Store Information (Sólo Administrador)
              if (authState.isAdmin) ...[
                Row(
                  children: [
                    const Icon(Icons.store_outlined, color: ColorTokens.lightBrandPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text('INFORMACIÓN DEL NEGOCIO', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'Nombre Comercial',
                  hint: 'ALFA GAMA STORE',
                  controller: _storeNameCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'NIT / RUT',
                        hint: '900.123.456-7',
                        controller: _nitCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomPhoneInput(
                        label: 'Teléfono',
                        hint: '300 123 4567',
                        controller: _phoneCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Dirección Comercial',
                  hint: 'Cra 5 #12-34, Valledupar',
                  controller: _addressCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Mensaje al Pie del Recibo POS',
                  hint: '¡Gracias por su compra! Conservar este recibo para cambios',
                  controller: _footerCtrl,
                ),
                const SizedBox(height: 20),
              ],

              // Section 2: Preferences Toggles
              Row(
                children: [
                  const Icon(Icons.tune_outlined, color: ColorTokens.lightBrandPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text('PREFERENCIAS DEL SISTEMA POS', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: ColorTokens.lightSurfacePrimary,
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: BorderShadowTokens.shadow3DCard,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Sonido al escanear código', style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text('Emitir bip sonoro al detectar un SKU con la cámara', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                      value: _soundOnScan,
                      activeThumbColor: ColorTokens.lightBrandPrimary,
                      onChanged: (val) {
                        setState(() {
                          _soundOnScan = val;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text('Impresión automática de ticket', style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text('Abrir diálogo de impresión inmediatamente al finalizar venta', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                      value: _autoPrintReceipt,
                      activeThumbColor: ColorTokens.lightBrandPrimary,
                      onChanged: (val) {
                        setState(() {
                          _autoPrintReceipt = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 3: Administración y Módulos
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, color: ColorTokens.lightBrandPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text('ADMINISTRACIÓN Y OPERACIONES', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: ColorTokens.lightSurfacePrimary,
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: BorderShadowTokens.shadow3DCard,
                ),
                child: ListTile(
                  tileColor: ColorTokens.lightSurfacePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.point_of_sale, color: ColorTokens.lightBrandPrimary),
                  title: Text('Arqueo & Cierre de Caja', style: FontTokens.bodyLarge.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text('Apertura de turno, control de efectivo y gastos', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: ColorTokens.lightTextSecondary),
                  onTap: () => context.push('/cash-shift'),
                ),
              ),
              if (authState.isAdmin) ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: ColorTokens.lightSurfacePrimary,
                    border: Border.all(color: ColorTokens.lightBorderSubtle),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: BorderShadowTokens.shadow3DCard,
                  ),
                  child: ListTile(
                    tileColor: ColorTokens.lightSurfacePrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.people_alt_outlined, color: ColorTokens.lightBrandPrimary),
                    title: Text('Gestión de Usuarios y Empleados', style: FontTokens.bodyLarge.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text('Crear usuarios, asignar permisos y cambiar roles (Empleado vs Admin)', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary, fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: ColorTokens.lightTextSecondary),
                    onTap: () => context.push('/user-management'),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              CustomButton(
                text: 'Guardar cambios',
                isLoading: _isSaving,
                onPressed: _saveSettings,
              ),
              const SizedBox(height: 14),

              // App Version Card
              Center(
                child: Column(
                  children: [
                    Text('AlfaGamaStore v1.0.5', style: FontTokens.label.copyWith(color: ColorTokens.textDim)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
