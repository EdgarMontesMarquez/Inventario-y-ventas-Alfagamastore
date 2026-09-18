import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';

import 'core/services/offline_sync_manager.dart';
import 'shared/providers/repository_providers.dart';
import 'shared/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO', null);

  // Inicializar cliente Supabase para el proyecto AlfaGamaStore
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  // Inicializar Firebase Push Notifications
  await PushNotificationService().initialize();

  // Modo inmersivo para ocultar la barra de navegación del SO (aparece solo al hacer gesto swipe)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Inicializar sincronizador offline y conectar con Riverpod
    OfflineSyncManager().initialize(
      onRefresh: () {
        if (mounted) {
          ref.invalidate(productsFutureProvider);
          ref.invalidate(salesFutureProvider);
          ref.invalidate(creditsFutureProvider);
          ref.invalidate(customersFutureProvider);
          ref.invalidate(activeCashShiftProvider);
          ref.read(settingsProvider.notifier).loadSettings();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Alfa Gama Store ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
    );
  }
}

