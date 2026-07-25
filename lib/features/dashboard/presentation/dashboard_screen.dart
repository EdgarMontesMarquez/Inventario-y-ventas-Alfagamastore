import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsFutureProvider);
    final salesAsync = ref.watch(salesFutureProvider);
    final creditsAsync = ref.watch(creditsFutureProvider);

    final dateFmt = DateFormat("EEEE, d 'de' MMMM", 'es_CO');
    final timeFmt = DateFormat('hh:mm a', 'es_CO');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 50),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ALFA GAMA STORE',
                    style: FontTokens.label.copyWith(
                      color: ColorTokens.text,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'MODA · CALIDAD · ESTILO',
                    style: FontTokens.label.copyWith(
                      color: ColorTokens.textDim,
                      fontSize: 8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20, color: ColorTokens.lightTextSecondary),
            onPressed: () {
              context.push('/settings');
            },
            tooltip: 'Configuración',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 20, color: ColorTokens.statusDanger),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando resumen...'),
        error: (err, stack) => ErrorState(
          title: 'Error al cargar resumen',
          message: err.toString(),
          onRetry: () {
            ref.invalidate(productsFutureProvider);
            ref.invalidate(salesFutureProvider);
            ref.invalidate(creditsFutureProvider);
          },
        ),
        data: (products) {
          return salesAsync.when(
            loading: () => const LoadingSpinner(message: 'Cargando ventas...'),
            error: (err, stack) => ErrorState(
              title: 'Error en ventas',
              message: err.toString(),
            ),
            data: (sales) {
              return creditsAsync.when(
                loading: () => const LoadingSpinner(message: 'Cargando créditos...'),
                error: (err, stack) => ErrorState(
                  title: 'Error en créditos',
                  message: err.toString(),
                ),
                data: (credits) {
                  final now = DateTime.now();

                  // Cómputo de Ventas en Zona Horaria Local
                  final todaySales = sales.where((s) {
                    final localDate = s.createdAt.toLocal();
                    return localDate.year == now.year &&
                        localDate.month == now.month &&
                        localDate.day == now.day;
                  }).toList();

                  final todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.total);

                  // Cómputo de Créditos
                  final totalCreditReceivable = credits.fold(0.0, (sum, c) => sum + c.pendingBalance);
                  final activeCredits = credits.where((c) => c.status != 'finalizado').toList();
                  final creditsInMora = credits.where((c) => c.status == 'mora').toList();

                  // Cómputo de Inventario
                  final lowStock = products.where((p) => p.stock <= p.minStock && p.stock > 0).toList();
                  final outOfStock = products.where((p) => p.stock == 0).toList();

                  final salesSparkline = sales.isEmpty
                      ? [0.0, 10.0, 25.0, 50.0]
                      : sales.reversed.take(6).map((s) => s.total).toList();

                  final monthSales = sales.where((s) {
                    final localDate = s.createdAt.toLocal();
                    return localDate.year == now.year && localDate.month == now.month;
                  }).toList();
                  final monthRevenue = monthSales.fold(0.0, (sum, s) => sum + s.total);

                  final yearSales = sales.where((s) {
                    final localDate = s.createdAt.toLocal();
                    return localDate.year == now.year;
                  }).toList();
                  final yearRevenue = yearSales.fold(0.0, (sum, s) => sum + s.total);

                  final authState = ref.watch(authProvider);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productsFutureProvider);
                      ref.invalidate(salesFutureProvider);
                      ref.invalidate(creditsFutureProvider);
                    },
                    backgroundColor: ColorTokens.surfaceElevated,
                    color: ColorTokens.primary,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con Fecha Actual
                          Text(
                            dateFmt.format(now).toUpperCase(),
                            style: FontTokens.label.copyWith(color: ColorTokens.textMuted),
                          ),
                          const SizedBox(height: 12),

                          // Banner Informativo de Caja Activa
                          Consumer(
                            builder: (ctx, ref, _) {
                              final shiftAsync = ref.watch(activeCashShiftProvider);
                              final isOpen = shiftAsync.asData?.value != null && shiftAsync.asData!.value!.isOpen;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isOpen ? ColorTokens.primary.withAlpha(20) : ColorTokens.warning.withAlpha(20),
                                  border: Border.all(color: isOpen ? ColorTokens.primary.withAlpha(80) : ColorTokens.warning.withAlpha(80)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOpen ? Icons.point_of_sale : Icons.lock_clock_outlined,
                                      color: isOpen ? ColorTokens.primary : ColorTokens.warning,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isOpen ? 'Caja Abierta (Turno Activo)' : 'Caja Cerrada (Turno Pendiente)',
                                            style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            isOpen ? 'Ingresa para registrar gastos o realizar el cierre' : 'Abre caja con la base inicial para operar el turno',
                                            style: FontTokens.bodySmall.copyWith(color: ColorTokens.textDim),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: isOpen ? ColorTokens.primary : ColorTokens.warning,
                                         foregroundColor: Colors.white,
                                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                         minimumSize: Size.zero,
                                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                       ),
                                       onPressed: () => context.push('/cash-shift'),
                                       child: Text(
                                         isOpen ? 'Ver Caja' : 'Abrir',
                                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                       ),
                                     ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Malla de Métricas Resumen
                          if (authState.isEmpleado) ...[
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.2,
                              children: [
                                MetricCard(
                                  label: 'Ventas hoy',
                                  value: CurrencyUtils.format(todayRevenue),
                                  subtitle: '${todaySales.length} transacciones',
                                  accentColor: ColorTokens.primary,
                                ),
                                MetricCard(
                                  label: 'Abonos recaudados',
                                  value: CurrencyUtils.format(credits.fold(0.0, (sum, c) => sum + c.totalPaid)),
                                  subtitle: 'cuotas cobradas',
                                  accentColor: ColorTokens.secondary,
                                ),
                              ],
                            ),
                          ] else ...[
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.2,
                              children: [
                                MetricCard(
                                  label: 'Ventas del día',
                                  value: CurrencyUtils.format(todayRevenue),
                                  subtitle: '${todaySales.length} ventas hoy',
                                  accentColor: ColorTokens.primary,
                                  sparklineData: salesSparkline,
                                ),
                                MetricCard(
                                  label: 'Ventas del mes',
                                  value: CurrencyUtils.format(monthRevenue),
                                  subtitle: '${monthSales.length} ventas mes',
                                  accentColor: ColorTokens.secondary,
                                ),
                                MetricCard(
                                  label: 'Ventas del año',
                                  value: CurrencyUtils.format(yearRevenue),
                                  subtitle: '${yearSales.length} ventas año',
                                  accentColor: ColorTokens.warning,
                                ),
                                MetricCard(
                                  label: 'Por cobrar',
                                  value: CurrencyUtils.format(totalCreditReceivable),
                                  subtitle: '${activeCredits.length} activos',
                                  accentColor: ColorTokens.secondary,
                                ),
                                MetricCard(
                                  label: 'Cobrado créditos',
                                  value: CurrencyUtils.format(credits.fold(0.0, (sum, c) => sum + c.totalPaid)),
                                  subtitle: 'recaudo total',
                                  accentColor: ColorTokens.primary,
                                ),
                                MetricCard(
                                  label: 'En mora',
                                  value: '${creditsInMora.length}',
                                  subtitle: 'atrasados',
                                  accentColor: creditsInMora.isNotEmpty ? ColorTokens.error : ColorTokens.textDim,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Sección de Alertas de Stock
                          if (lowStock.isNotEmpty || outOfStock.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.warning_amber_rounded,
                              title: 'ALERTAS DE STOCK',
                              color: ColorTokens.warning,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: ColorTokens.surface,
                                border: Border.all(color: ColorTokens.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  ...outOfStock.map((p) => _buildAlertRow(
                                        name: p.name,
                                        sku: p.sku,
                                        msg: 'Sin stock',
                                        color: ColorTokens.error,
                                      )),
                                  ...lowStock.map((p) => _buildAlertRow(
                                        name: p.name,
                                        sku: p.sku,
                                        msg: '${p.stock} uds',
                                        color: ColorTokens.warning,
                                      )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Sección de Ventas de Hoy
                          if (todaySales.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.receipt_long_outlined,
                              title: 'VENTAS DE HOY',
                              color: ColorTokens.textMuted,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: ColorTokens.surface,
                                border: Border.all(color: ColorTokens.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: List.generate(todaySales.take(5).length, (idx) {
                                  final recentTop = todaySales.take(5).toList();
                                  final s = recentTop[idx];
                                  final isLast = idx == todaySales.length - 1;
                                  final summary = s.items.map((i) => i.productName).join(', ');

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: isLast ? BorderSide.none : const BorderSide(color: ColorTokens.border),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                summary,
                                                style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${timeFmt.format(s.createdAt.toLocal())} · ${s.paymentMethod}',
                                                style: FontTokens.label.copyWith(color: ColorTokens.textDim),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          CurrencyUtils.format(s.total),
                                          style: FontTokens.moneyMedium.copyWith(
                                            color: ColorTokens.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: FontTokens.label.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertRow({
    required String name,
    required String sku,
    required String msg,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColorTokens.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              Text(sku, style: FontTokens.label.copyWith(color: ColorTokens.textDim)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              msg,
              style: FontTokens.label.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
