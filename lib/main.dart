import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutomaticDailyNotification();
    });
  }

  static bool _hasCheckedToday = false;

  void _checkAutomaticDailyNotification() {
    if (_hasCheckedToday) return;
    _hasCheckedToday = true;

    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser == null) return;

        final res = await client
            .from('credits')
            .select('customer_name, credit_installments(amount, paid_amount, is_paid, due_date)')
            .neq('status', 'finalizado');

        final credits = res as List? ?? [];
        if (credits.isEmpty) return;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        int dueTodayCount = 0;
        int overdueCount = 0;
        double totalDueToday = 0;

        for (final c in credits) {
          final insts = c['credit_installments'] as List? ?? [];
          for (final inst in insts) {
            final quotaVal = (inst['amount'] as num?)?.toDouble() ?? 0;
            final paidVal = (inst['paid_amount'] as num?)?.toDouble() ?? 0;
            final isPaid = inst['is_paid'] == true || paidVal >= quotaVal;
            if (isPaid) continue;

            final pendingQuota = quotaVal - paidVal;
            final dueDateStr = (inst['due_date'] as String?)?.split('T')[0];
            if (dueDateStr == null) continue;
            final dueDate = DateTime.tryParse(dueDateStr);
            if (dueDate == null) continue;

            final diffDays = today.difference(DateTime(dueDate.year, dueDate.month, dueDate.day)).inDays;
            if (diffDays == 0) {
              dueTodayCount++;
              totalDueToday += pendingQuota;
            } else if (diffDays > 0) {
              overdueCount++;
            }
          }
        }

        if (dueTodayCount > 0 || overdueCount > 0) {
          final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
          final formattedHoy = fmt.format(totalDueToday);

          String body = '';
          if (dueTodayCount > 0 && overdueCount > 0) {
            body = '📅 $dueTodayCount cobro(s) para hoy ($formattedHoy) · ⚠️ $overdueCount en mora. Toca para ver.';
          } else if (dueTodayCount > 0) {
            body = '📅 Tienes $dueTodayCount cobro(s) programados para hoy por un total de $formattedHoy.';
          } else {
            body = '⚠️ Tienes $overdueCount cliente(s) con cuotas vencidas en mora.';
          }

          PushNotificationService().showInAppNotificationBanner(
            title: '🔔 Alfa Gama Store · Cobranza del Día',
            body: body,
          );
        }
      } catch (e) {
        debugPrint('Aviso en chequeo automático de cobranza: $e');
      }
    });
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

