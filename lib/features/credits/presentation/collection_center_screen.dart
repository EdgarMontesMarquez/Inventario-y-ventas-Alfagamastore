import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../shared/models/credit.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state.dart';

class CollectionCenterScreen extends ConsumerStatefulWidget {
  const CollectionCenterScreen({super.key});

  @override
  ConsumerState<CollectionCenterScreen> createState() => _CollectionCenterScreenState();
}

class _CollectionCenterScreenState extends ConsumerState<CollectionCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsAppMessage(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El cliente no tiene un teléfono registrado.'),
            backgroundColor: ColorTokens.statusWarning,
          ),
        );
      }
      return;
    }

    final formattedPhone = cleanPhone.length == 10 ? '57$cleanPhone' : cleanPhone;
    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp.'),
            backgroundColor: ColorTokens.statusDanger,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(creditsFutureProvider);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Cobranza'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: ColorTokens.lightBrandPrimary,
          unselectedLabelColor: ColorTokens.lightTextSecondary,
          indicatorColor: ColorTokens.lightBrandPrimary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.today_outlined, size: 20),
              text: 'Para Cobrar Hoy',
            ),
            Tab(
              icon: Icon(Icons.warning_amber_rounded, size: 20),
              text: 'En Mora / Vencidos',
            ),
          ],
        ),
      ),
      body: creditsAsync.when(
        loading: () => const LoadingSpinner(message: 'Analizando cartera y cobros...'),
        error: (err, stack) => Center(child: Text('Error al cargar datos: $err')),
        data: (credits) {
          final activeCredits = credits.where((c) => c.status != 'finalizado').toList();

          // 1. Filtrar cuotas que vencen hoy
          final List<_DueItem> todayItems = [];
          // 2. Filtrar cuotas en mora
          final List<_DueItem> overdueItems = [];

          for (final credit in activeCredits) {
            for (final inst in credit.installments) {
              if (inst.paidAmount >= inst.quotaValue) continue;

              final instDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
              final diffDays = today.difference(instDate).inDays;

              if (diffDays == 0) {
                todayItems.add(_DueItem(
                  credit: credit,
                  installment: inst,
                  daysInArrears: 0,
                ));
              } else if (diffDays > 0) {
                overdueItems.add(_DueItem(
                  credit: credit,
                  installment: inst,
                  daysInArrears: diffDays,
                ));
              }
            }
          }

          // Ordenar las cuotas en mora de mayor atraso a menor
          overdueItems.sort((a, b) => b.daysInArrears.compareTo(a.daysInArrears));

          final totalHoy = todayItems.fold(0.0, (sum, i) => sum + (i.installment.quotaValue - i.installment.paidAmount));
          final totalMora = overdueItems.fold(0.0, (sum, i) => sum + (i.installment.quotaValue - i.installment.paidAmount));

          return Column(
            children: [
              // Barra de resumen superior
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: ColorTokens.lightBgSecondary,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ColorTokens.lightBorderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOY: ${todayItems.length} CUOTA(S)',
                              style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.format(totalHoy),
                              style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightBrandPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ColorTokens.lightBorderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MORA: ${overdueItems.length} CUOTA(S)',
                              style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.statusDanger, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.format(totalMora),
                              style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.statusDanger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido de las pestañas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaña 1: Para Cobrar Hoy
                    RefreshIndicator(
                      onRefresh: () async => ref.invalidate(creditsFutureProvider),
                      child: todayItems.isEmpty
                          ? const Center(
                              child: EmptyState(
                                title: 'Sin cobros pendientes para hoy',
                                description: '¡Excelente! No tienes cuotas programadas para cobrar el día de hoy.',
                                icon: Icons.check_circle_outline,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: todayItems.length,
                              separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                              itemBuilder: (ctx, idx) {
                                final item = todayItems[idx];
                                final credit = item.credit;
                                final inst = item.installment;
                                final pendingVal = inst.quotaValue - inst.paidAmount;

                                final message = 'Hola ${credit.clientName}, te saludamos de Alfa Gama Store. '
                                    'Te recordamos cordialmente que el día de hoy vence la cuota N° ${inst.quotaNumber} '
                                    'de tu crédito por valor de ${CurrencyUtils.format(pendingVal)}. '
                                    '¡Agradecemos tu puntualidad!';

                                return _buildCollectionCard(
                                  context: context,
                                  item: item,
                                  isOverdue: false,
                                  dateFmt: dateFmt,
                                  whatsappMessage: message,
                                );
                              },
                            ),
                    ),

                    // Pestaña 2: En Mora
                    RefreshIndicator(
                      onRefresh: () async => ref.invalidate(creditsFutureProvider),
                      child: overdueItems.isEmpty
                          ? const Center(
                              child: EmptyState(
                                title: 'Sin clientes en mora',
                                description: 'Tu cartera está 100% al día. ¡Felicidades!',
                                icon: Icons.verified_outlined,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: overdueItems.length,
                              separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                              itemBuilder: (ctx, idx) {
                                final item = overdueItems[idx];
                                final credit = item.credit;
                                final inst = item.installment;
                                final pendingVal = inst.quotaValue - inst.paidAmount;

                                final message = 'Hola ${credit.clientName}, te saludamos de Alfa Gama Store. '
                                    'Te informamos que tu cuota N° ${inst.quotaNumber} por valor de ${CurrencyUtils.format(pendingVal)} '
                                    'presenta ${item.daysInArrears} día(s) de vencimiento (${dateFmt.format(inst.dueDate)}). '
                                    'Por favor comunícate con nosotros para acordar el pago.';

                                return _buildCollectionCard(
                                  context: context,
                                  item: item,
                                  isOverdue: true,
                                  dateFmt: dateFmt,
                                  whatsappMessage: message,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCollectionCard({
    required BuildContext context,
    required _DueItem item,
    required bool isOverdue,
    required DateFormat dateFmt,
    required String whatsappMessage,
  }) {
    final credit = item.credit;
    final inst = item.installment;
    final pendingQuota = inst.quotaValue - inst.paidAmount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? ColorTokens.statusDanger.withAlpha(60) : ColorTokens.lightBorderSubtle,
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: BorderShadowTokens.shadowClayCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Cliente y Badge de estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isOverdue ? ColorTokens.statusDanger.withAlpha(20) : ColorTokens.lightBrandPrimary.withAlpha(20),
                child: Text(
                  credit.clientName.isNotEmpty ? credit.clientName[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOverdue ? ColorTokens.statusDanger : ColorTokens.lightBrandPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.clientName,
                      style: FontTokens.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      credit.products,
                      style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorTokens.statusDanger.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorTokens.statusDanger.withAlpha(80)),
                  ),
                  child: Text(
                    '⚠️ ${item.daysInArrears} DÍAS DE MORA',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: ColorTokens.statusDanger,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorTokens.lightBrandPrimary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorTokens.lightBrandPrimary.withAlpha(60)),
                  ),
                  child: Text(
                    'VENCE HOY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: ColorTokens.lightBrandPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Datos de la cuota
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUOTA N°', style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.lightTextSecondary)),
                  Text(
                    '${inst.quotaNumber} de ${credit.totalQuotas}',
                    style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FECHA VENCIMIENTO', style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.lightTextSecondary)),
                  Text(
                    dateFmt.format(inst.dueDate),
                    style: FontTokens.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? ColorTokens.statusDanger : ColorTokens.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VALOR CUOTA', style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.lightTextSecondary)),
                  Text(
                    CurrencyUtils.format(pendingQuota),
                    style: FontTokens.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? ColorTokens.statusDanger : ColorTokens.lightBrandPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botones de acción rápida
          Row(
            children: [
              // Botón WhatsApp
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendWhatsAppMessage(credit.clientPhone, whatsappMessage),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16, color: ColorTokens.statusSuccess),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: ColorTokens.statusSuccess, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ColorTokens.statusSuccess),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Llamar si tiene teléfono
              if (credit.clientPhone.isNotEmpty) ...[
                IconButton(
                  onPressed: () => _makePhoneCall(credit.clientPhone),
                  icon: const Icon(Icons.phone_outlined, size: 18, color: ColorTokens.lightBrandPrimary),
                  tooltip: 'Llamar al cliente',
                  style: IconButton.styleFrom(
                    backgroundColor: ColorTokens.lightBrandPrimary.withAlpha(15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Botón Ver Detalle
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/credits/${credit.id}');
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  label: const Text('Ver Crédito', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorTokens.lightBrandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueItem {
  final Credit credit;
  final CreditInstallment installment;
  final int daysInArrears;

  _DueItem({
    required this.credit,
    required this.installment,
    required this.daysInArrears,
  });
}
