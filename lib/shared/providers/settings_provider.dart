import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_settings.dart';
import '../../features/auth/providers/auth_provider.dart';

class SettingsNotifier extends Notifier<StoreSettings> {
  @override
  StoreSettings build() {
    _fetchSettingsFromSupabase();
    return const StoreSettings(
      storeName: 'Alfa Gama Store',
      nit: '900.123.456-7',
      phone: '300 123 4567',
      address: 'Cra 5 #12-34',
      receiptFooter: '¡GRACIAS POR SU COMPRA! Conservar este recibo para cambios',
      currencySymbol: 'COP (\$)',
      soundOnScan: true,
      autoPrintReceipt: true,
    );
  }

  void loadSettings() {
    _fetchSettingsFromSupabase();
  }

  Future<void> _fetchSettingsFromSupabase() async {
    Map<String, dynamic>? storeRes;
    try {
      storeRes = await Supabase.instance.client
          .from('store_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error fetching store_settings: $e');
    }

    Map<String, dynamic>? profileRes;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        profileRes = await Supabase.instance.client
            .from('profiles')
            .select('sound_on_scan, auto_print_receipt')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        debugPrint('Error fetching profile preferences: $e');
      }
    }

    state = StoreSettings(
      storeName: storeRes?['store_name'] ?? 'Alfa Gama Store',
      nit: storeRes?['nit'] ?? '900.123.456-7',
      phone: storeRes?['phone'] ?? '300 123 4567',
      address: storeRes?['address'] ?? 'Cra 5 #12-34',
      receiptFooter: storeRes?['receipt_footer'] ?? '¡GRACIAS POR SU COMPRA! Conservar este recibo para cambios',
      currencySymbol: 'COP (\$)',
      soundOnScan: (profileRes?['sound_on_scan'] as bool?) ?? true,
      autoPrintReceipt: (profileRes?['auto_print_receipt'] as bool?) ?? true,
    );
  }

  Future<void> updateSettings(StoreSettings newSettings) async {
    state = newSettings;

    // 1. Guardar configuraciones generales del negocio (solo si es admin)
    final isAdmin = ref.read(authProvider).isAdmin;
    if (isAdmin) {
      try {
        await Supabase.instance.client.from('store_settings').upsert({
          'id': 1,
          'store_name': newSettings.storeName,
          'nit': newSettings.nit,
          'phone': newSettings.phone,
          'address': newSettings.address,
          'receipt_footer': newSettings.receiptFooter,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error updating store_settings: $e');
      }
    }

    // 2. Guardar preferencias individuales del usuario en su perfil de Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'sound_on_scan': newSettings.soundOnScan,
          'auto_print_receipt': newSettings.autoPrintReceipt,
        }).eq('id', userId);
      } catch (e) {
        debugPrint('Error updating user profile preferences: $e');
      }
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, StoreSettings>(() {
  return SettingsNotifier();
});
