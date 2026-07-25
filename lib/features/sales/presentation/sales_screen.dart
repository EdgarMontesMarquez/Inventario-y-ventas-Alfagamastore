import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/widgets/receipt_modal.dart';
import '../../../shared/widgets/image_viewer_modal.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  String _formatRelDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'HOY';
    if (date == yesterday) return 'AYER';
    return DateFormat('d MMM', 'es_CO').format(dt).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesFutureProvider);
    final currencyFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final timeFmt = DateFormat('hh:mm a', 'es_CO');

    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: [
          if (authState.isAdmin)
            IconButton(
              icon: const Icon(
                Icons.bar_chart_outlined,
                size: 22,
                color: ColorTokens.lightBrandPrimary,
              ),
              onPressed: () {
                context.push('/reports');
              },
              tooltip: 'Reportes y analítica',
            ),
        ],
      ),
      body: salesAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando ventas...'),
        error: (err, stack) => ErrorState(
          title: 'Error al cargar ventas',
          message: err.toString(),
          onRetry: () => ref.invalidate(salesFutureProvider),
        ),
        data: (sales) {
          if (sales.isEmpty) {
            return const EmptyState(
              title: 'Sin ventas',
              description: 'Aún no has registrado ninguna venta en el sistema.',
              icon: Icons.receipt_long_outlined,
            );
          }

          // Ordenar ventas por fecha descendente
          final sortedSales = List<Sale>.from(sales)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Agrupar ventas por etiqueta de fecha
          final Map<String, List<Sale>> groupedSales = {};
          for (var s in sortedSales) {
            final key = _formatRelDate(s.createdAt.toLocal());
            groupedSales.putIfAbsent(key, () => []).add(s);
          }

          final now = DateTime.now();
          final todaySales = sales.where((s) {
            final local = s.createdAt.toLocal();
            return local.year == now.year &&
                local.month == now.month &&
                local.day == now.day;
          });
          final todayTotal = todaySales.fold(0.0, (sum, s) => sum + s.total);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(salesFutureProvider);
            },
            backgroundColor: ColorTokens.surfaceElevated,
            color: ColorTokens.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REGISTRO DE VENTAS',
                            style: FontTokens.label.copyWith(
                              color: ColorTokens.textMuted,
                            ),
                          ),
                          Text(
                            '${sales.length} registros',
                            style: FontTokens.h2,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'HOY',
                            style: FontTokens.label.copyWith(
                              color: ColorTokens.textMuted,
                            ),
                          ),
                          Text(
                            currencyFmt.format(todayTotal),
                            style: FontTokens.moneyMedium.copyWith(
                              color: ColorTokens.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 14),

                  // Lista Agrupada por Fecha
                  ...groupedSales.entries.map((entry) {
                    final dateLabel = entry.key;
                    final daySales = entry.value;
                    final dayTotal = daySales.fold(
                      0.0,
                      (sum, s) => sum + s.total,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateLabel,
                              style: FontTokens.label.copyWith(
                                color: ColorTokens.textMuted,
                              ),
                            ),
                            Text(
                              currencyFmt.format(dayTotal),
                              style: FontTokens.moneySmall.copyWith(
                                color: ColorTokens.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: daySales.length,
                          separatorBuilder: (context, idx) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final s = daySales[idx];
                            Color pmColor = s.paymentMethod == 'efectivo'
                                ? ColorTokens.primary
                                : s.paymentMethod == 'tarjeta'
                                ? ColorTokens.secondary
                                : ColorTokens.warning;

                            final hasReceipt =
                                s.receiptImageUrl != null &&
                                s.receiptImageUrl!.trim().isNotEmpty;

                            Widget buildSaleThumbnail() {
                              if (!hasReceipt) return const SizedBox.shrink();
                              final clean = s.receiptImageUrl!.trim();

                              Widget imgWidget;
                              if (clean.startsWith('data:image') ||
                                  clean.length > 500) {
                                try {
                                  final base64Str = clean.contains(',')
                                      ? clean.split(',').last
                                      : clean;
                                  final bytes = base64Decode(base64Str);
                                  imgWidget = Image.memory(
                                    bytes,
                                    fit: BoxFit.cover,
                                    width: 75,
                                    height: 75,
                                  );
                                } catch (_) {
                                  imgWidget = Container(
                                    width: 75,
                                    height: 75,
                                    color: ColorTokens.lightBgSecondary,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: ColorTokens.lightTextSecondary,
                                    ),
                                  );
                                }
                              } else if (clean.startsWith('http://') ||
                                  clean.startsWith('https://')) {
                                imgWidget = Image.network(
                                  clean,
                                  fit: BoxFit.cover,
                                  width: 75,
                                  height: 75,
                                  errorBuilder: (c, e, st) => Container(
                                    width: 75,
                                    height: 75,
                                    color: ColorTokens.lightBgSecondary,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: ColorTokens.lightTextSecondary,
                                    ),
                                  ),
                                );
                              } else {
                                final f = File(clean);
                                if (f.existsSync()) {
                                  imgWidget = Image.file(
                                    f,
                                    fit: BoxFit.cover,
                                    width: 75,
                                    height: 75,
                                  );
                                } else {
                                  imgWidget = Container(
                                    width: 75,
                                    height: 75,
                                    color: ColorTokens.lightBgSecondary,
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      color: ColorTokens.lightTextSecondary,
                                    ),
                                  );
                                }
                              }

                              return GestureDetector(
                                onTap: () => ImageViewerModal.show(
                                  context,
                                  imageUrl: clean,
                                  title: 'Comprobante de Venta',
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 75,
                                    height: 75,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        imgWidget,
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.fullscreen,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => ReceiptModal.show(context, s),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (hasReceipt) ...[
                                        buildSaleThumbnail(),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: s.items.map((item) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: RichText(
                                                          text: TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text: '${item.qty}× ',
                                                                style: FontTokens.label.copyWith(
                                                                  color: ColorTokens.lightBrandPrimary,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: item.productName,
                                                                style: FontTokens.bodyMedium.copyWith(
                                                                  color: ColorTokens.lightTextPrimary,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  CurrencyUtils.format(s.total),
                                                  style: FontTokens.moneyMedium.copyWith(
                                                    color: ColorTokens.lightBrandPrimary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  timeFmt.format(s.createdAt.toLocal()),
                                                  style: FontTokens.label.copyWith(
                                                    color: ColorTokens.lightTextSecondary,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: pmColor.withAlpha(30),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    s.paymentMethod.toUpperCase(),
                                                    style: FontTokens.label.copyWith(
                                                      color: pmColor,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (s.note.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              const Divider(height: 1),
                                              const SizedBox(height: 6),
                                              Text(
                                                s.note,
                                                style: FontTokens.bodySmall.copyWith(
                                                  color: ColorTokens.lightTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
