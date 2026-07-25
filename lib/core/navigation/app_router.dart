import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/credits/presentation/credits_screen.dart';
import '../../features/credits/presentation/credit_detail_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/cash_shift/presentation/cash_shift_screen.dart';
import '../../features/users/presentation/user_management_screen.dart';
import '../../shared/widgets/navigation_shell.dart';
import '../../core/design_system/widgets/custom_overlays.dart';
import '../../features/sales/presentation/widgets/new_sale_sheet.dart';

import '../design_system/tokens/color_tokens.dart';
import '../../shared/providers/repository_providers.dart';
import '../../features/auth/presentation/splash_screen.dart';

import '../../features/credits/presentation/public_credit_lookup_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isAuthenticated;
      final loc = state.matchedLocation;

      if (!isLoggedIn && loc != '/login' && loc != '/splash' && !loc.startsWith('/consulta-credito')) {
        return '/login';
      }

      if (isLoggedIn && (loc == '/login' || loc == '/splash')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          int getIndex() {
            final loc = state.matchedLocation;
            if (loc.startsWith('/dashboard')) return 0;
            if (loc.startsWith('/inventory')) return 1;
            if (loc.startsWith('/credits')) return 2;
            if (loc.startsWith('/sales')) return 3;
            return 0;
          }

          return Consumer(
            builder: (context, ref, _) {
              final lowStockCount = ref.watch(productsFutureProvider).asData?.value.where((p) => p.stock <= p.minStock && p.stock > 0).length ?? 0;
              final overdueCreditsCount = ref.watch(creditsFutureProvider).asData?.value.where((c) => c.status == 'mora').length ?? 0;

              return NavigationShell(
                currentIndex: getIndex(),
                body: child,
                lowStockCount: lowStockCount,
                overdueCreditsCount: overdueCreditsCount,
                onTabSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go('/dashboard');
                      break;
                    case 1:
                      context.go('/inventory');
                      break;
                    case 2:
                      context.go('/credits');
                      break;
                    case 3:
                      context.go('/sales');
                      break;
                  }
                },
                onFABPressed: () {
                  final activeShift = ref.read(activeCashShiftProvider).asData?.value;
                  if (activeShift == null || !activeShift.isOpen) {
                    final ctx = rootNavigatorKey.currentContext ?? context;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: const Text('Debe realizar la Apertura de Caja antes de poder registrar ventas.'),
                        backgroundColor: ColorTokens.statusWarning,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  CustomOverlays.showBottomSheet(
                    context: rootNavigatorKey.currentContext ?? context,
                    title: 'Nueva venta POS',
                    child: const NewSaleSheet(),
                  );
                },
              );
            },
          );
        },

        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/credits',
            builder: (context, state) => const CreditsScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/cash-shift',
        builder: (context, state) => const CashShiftScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/user-management',
        builder: (context, state) => const UserManagementScreen(),
      ),
      // La ruta de detalle de crédito está por fuera del Bottom Nav Shell para ocultar la barra
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/credits/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CreditDetailScreen(creditId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/consulta-credito',
        builder: (context, state) {
          final docType = state.uri.queryParameters['doc_type'] ?? state.uri.queryParameters['tipo'];
          final docId = state.uri.queryParameters['doc_id'] ?? state.uri.queryParameters['cedula'] ?? state.uri.queryParameters['id'];
          return PublicCreditLookupScreen(
            initialDocType: docType,
            initialDocId: docId,
          );
        },
      ),
    ],
  );
});
