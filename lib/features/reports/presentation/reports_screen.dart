import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/services/csv_exporter_service.dart';
import '../../../core/utils/currency_formatter.dart';


class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesFutureProvider);
    final productsAsync = ref.watch(productsFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Analítica'),
      ),
      body: salesAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando reportes analíticos...'),
        error: (err, stack) => ErrorState(
          title: 'Error en reportes',
          message: err.toString(),
          onRetry: () => ref.invalidate(salesFutureProvider),
        ),
        data: (sales) {
          return productsAsync.when(
            loading: () => const LoadingSpinner(message: 'Cargando datos de inventario...'),
            error: (err, stack) => ErrorState(title: 'Error', message: err.toString()),
            data: (products) {
              if (sales.isEmpty) {
                return const EmptyState(
                  title: 'Sin datos para reportes',
                  description: 'Registra tus primeras ventas para visualizar los indicadores de rendimiento.',
                  icon: Icons.bar_chart_outlined,
                );
              }

              final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.total);
              final totalTransactions = sales.length;
              final avgTicket = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

              // Aggregations by category
              final Map<String, double> categorySales = {};
              for (var s in sales) {
                for (var item in s.items) {
                  final prod = products.where((p) => p.id == item.productId).firstOrNull;
                  final cat = prod?.category ?? 'Otros';
                  categorySales[cat] = (categorySales[cat] ?? 0.0) + (item.unitPrice * item.qty);
                }
              }

              // Aggregations by Payment Method
              final Map<String, double> pmSales = {};
              for (var s in sales) {
                pmSales[s.paymentMethod] = (pmSales[s.paymentMethod] ?? 0.0) + s.total;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BALANCE GENERAL DE VENTAS', style: FontTokens.label.copyWith(color: ColorTokens.textMuted)),
                    const SizedBox(height: 8),

                    // Top 3 KPI Grid Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard('INGRESOS', CurrencyUtils.format(totalRevenue), ColorTokens.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildKpiCard('TICKET PROMEDIO', CurrencyUtils.format(avgTicket), ColorTokens.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Category Distribution Progress Bars
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorTokens.surface,
                        border: Border.all(color: ColorTokens.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_outline, color: ColorTokens.secondary, size: 18),
                              const SizedBox(width: 8),
                              Text('VENTAS POR CATEGORÍA', style: FontTokens.label.copyWith(color: ColorTokens.secondary)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...categorySales.entries.map((entry) {
                            final pct = totalRevenue > 0 ? (entry.value / totalRevenue) * 100 : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.key, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                                      Text(
                                        '${CurrencyUtils.format(entry.value)} (${pct.toStringAsFixed(1)}%)',
                                        style: FontTokens.label.copyWith(color: ColorTokens.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ProgressBar(percentage: pct, color: ColorTokens.secondary),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment Method Distribution Cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorTokens.surface,
                        border: Border.all(color: ColorTokens.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: ColorTokens.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('DISTRIBUCIÓN POR MÉTODO DE PAGO', style: FontTokens.label.copyWith(color: ColorTokens.primary)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: pmSales.entries.map((entry) {
                              final pct = totalRevenue > 0 ? (entry.value / totalRevenue) * 100 : 0.0;
                              Color color = entry.key == 'efectivo'
                                  ? ColorTokens.primary
                                  : entry.key == 'tarjeta'
                                      ? ColorTokens.secondary
                                      : ColorTokens.warning;

                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    border: Border.all(color: color.withAlpha(60)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.key.toUpperCase(), style: FontTokens.label.copyWith(color: color, fontSize: 9)),
                                      const SizedBox(height: 4),
                                      Text(CurrencyUtils.format(entry.value), style: FontTokens.moneySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
                                      Text('${pct.toStringAsFixed(1)}%', style: FontTokens.label.copyWith(color: ColorTokens.textDim, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sección de Exportación a Excel / CSV
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorTokens.surface,
                        border: Border.all(color: ColorTokens.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.file_download_outlined, color: ColorTokens.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('EXPORTACIÓN DE DATOS (EXCEL / CSV)', style: FontTokens.label.copyWith(color: ColorTokens.primary)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Descarga o comparte los respaldos completos de la tienda:', style: FontTokens.bodySmall.copyWith(color: ColorTokens.textMuted)),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              side: const BorderSide(color: ColorTokens.primary),
                            ),
                            icon: const Icon(Icons.table_chart_outlined, color: ColorTokens.primary, size: 18),
                            label: const Text('Exportar Inventario Completo (.CSV)', style: TextStyle(color: ColorTokens.primary, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final prods = ref.read(productsFutureProvider).asData?.value ?? [];
                              await CsvExporterService.exportProductsCsv(prods);
                            },
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              side: const BorderSide(color: ColorTokens.secondary),
                            ),
                            icon: const Icon(Icons.receipt_long_outlined, color: ColorTokens.secondary, size: 18),
                            label: const Text('Exportar Historial de Ventas (.CSV)', style: TextStyle(color: ColorTokens.secondary, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final salesList = ref.read(salesFutureProvider).asData?.value ?? [];
                              await CsvExporterService.exportSalesCsv(salesList);
                            },
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              side: const BorderSide(color: ColorTokens.warning),
                            ),
                            icon: const Icon(Icons.credit_score_outlined, color: ColorTokens.warning, size: 18),
                            label: const Text('Exportar Créditos y Cartera (.CSV)', style: TextStyle(color: ColorTokens.warning, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final creditsList = ref.read(creditsFutureProvider).asData?.value ?? [];
                              await CsvExporterService.exportCreditsCsv(creditsList);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        border: Border.all(color: ColorTokens.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FontTokens.label.copyWith(fontSize: 9)),
          const SizedBox(height: 6),
          Text(value, style: FontTokens.moneyMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
