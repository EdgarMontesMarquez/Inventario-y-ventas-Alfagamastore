import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../core/design_system/widgets/custom_overlays.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../shared/models/cash_shift.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/models/sale.dart';
import '../../../shared/widgets/receipt_modal.dart';
import '../../../shared/widgets/image_viewer_modal.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';


final cashShiftHistoryFutureProvider = FutureProvider.autoDispose<List<CashShift>>((ref) async {
  return ref.watch(cashShiftRepositoryProvider).getShiftHistory();
});

final shiftSalesFutureProvider = FutureProvider.family.autoDispose<List<Sale>, CashShift>((ref, shift) async {
  final salesRepo = ref.watch(saleRepositoryProvider);
  final allSales = await salesRepo.getSales();
  final openedAt = shift.openedAt;
  final closedAt = shift.closedAt ?? DateTime.now();

  return allSales.where((sale) {
    final st = sale.createdAt;
    return st.isAfter(openedAt.subtract(const Duration(seconds: 5))) &&
           st.isBefore(closedAt.add(const Duration(seconds: 5)));
  }).toList();
});

class CashShiftScreen extends ConsumerStatefulWidget {
  const CashShiftScreen({super.key});

  @override
  ConsumerState<CashShiftScreen> createState() => _CashShiftScreenState();
}

class _CashShiftScreenState extends ConsumerState<CashShiftScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  void _openOpenShiftSheet(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider);
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Apertura de Caja',
      child: _OpenShiftSheet(
        userName: authState.email.isNotEmpty ? authState.email.split('@')[0] : 'Empleado',
        onSuccess: () {
          ref.invalidate(activeCashShiftProvider);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _openAddExpenseSheet(BuildContext context, WidgetRef ref, String shiftId) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Registrar Gasto / Egreso de Caja',
      child: _AddExpenseSheet(
        shiftId: shiftId,
        onSuccess: () {
          ref.invalidate(activeCashShiftProvider);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _openCloseShiftSheet(BuildContext context, WidgetRef ref, CashShift shift) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Cierre y Cuadre de Caja',
      child: _CloseShiftSheet(
        shift: shift,
        onSuccess: () {
          ref.invalidate(activeCashShiftProvider);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShiftAsync = ref.watch(activeCashShiftProvider);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arqueo & Cierre de Caja'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ColorTokens.primary,
          tabs: const [
            Tab(text: 'Caja Actual en Vivo'),
            Tab(text: 'Historial de Cierres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Caja Actual en Vivo
          activeShiftAsync.when(
            loading: () => const LoadingSpinner(message: 'Cargando estado de caja...'),
            error: (err, stack) => ErrorState(
              title: 'Error en caja',
              message: err.toString(),
              onRetry: () => ref.invalidate(activeCashShiftProvider),
            ),
            data: (shift) {
              if (shift == null || !shift.isOpen) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_clock_outlined, size: 72, color: ColorTokens.warning),
                        const SizedBox(height: 16),
                        Text('La caja se encuentra cerrada', style: FontTokens.h2),
                        const SizedBox(height: 8),
                        Text('Debes realizar la apertura con el monto inicial en efectivo para iniciar el turno.', textAlign: TextAlign.center, style: FontTokens.bodyMedium.copyWith(color: ColorTokens.textMuted)),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Abrir Caja (Apertura de Turno)',
                          icon: Icons.key_outlined,
                          onPressed: () => _openOpenShiftSheet(context, ref),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(activeCashShiftProvider),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card Estado de Caja
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ColorTokens.surface,
                          border: Border.all(color: ColorTokens.primary.withAlpha(80)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(color: ColorTokens.primary, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'CAJA ABIERTA · TURNO EN VIVO',
                                          style: FontTokens.label.copyWith(color: ColorTokens.primary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(dateFmt.format(shift.openedAt.toLocal()), style: FontTokens.label.copyWith(fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('TOTAL ESPERADO EN CAJÓN', style: FontTokens.label.copyWith(fontSize: 10, color: ColorTokens.textMuted)),
                            Text(
                              CurrencyUtils.format(shift.computedExpected),
                              style: FontTokens.h1.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold),
                            ),
                            Text('Responsable: ${shift.userName}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.textDim)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Desglose de Operaciones
                      Row(
                        children: [
                          Expanded(child: _buildMetric('BASE INICIAL', CurrencyUtils.format(shift.initialAmount), ColorTokens.text)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetric('VENTAS EFECTIVO', CurrencyUtils.format(shift.cashSales), ColorTokens.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildMetric('ABONOS EFECTIVO', CurrencyUtils.format(shift.cashCredits), ColorTokens.secondary)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetric('EGRESOS / GASTOS', CurrencyUtils.format(shift.totalExpenses), ColorTokens.error)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildMetric('VENTAS TRANSFERENCIA', CurrencyUtils.format(shift.transferSales), ColorTokens.secondary)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetric('TOTAL VENTAS DÍA', CurrencyUtils.format(shift.totalShiftSales), ColorTokens.primary)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lista de Gastos Registrados
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('GASTOS Y EGRESOS MENORES', style: FontTokens.label.copyWith(color: ColorTokens.textMuted)),
                          CustomButton(
                            text: '+ Gasto',
                            icon: Icons.remove_circle_outline,
                            isFullWidth: false,
                            onPressed: () => _openAddExpenseSheet(context, ref, shift.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (shift.expenses.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ColorTokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ColorTokens.border),
                          ),
                          child: Text('No hay egresos de caja registrados en este turno.', style: FontTokens.bodySmall.copyWith(color: ColorTokens.textDim)),
                        ),
                      ] else ...[
                        Container(
                          decoration: BoxDecoration(
                            color: ColorTokens.surface,
                            border: Border.all(color: ColorTokens.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: shift.expenses.length,
                            separatorBuilder: (context, itemIdx) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final ex = shift.expenses[idx];
                              return ListTile(
                                dense: true,
                                title: Text(ex.description, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(dateFmt.format(ex.createdAt.toLocal()), style: FontTokens.bodySmall),
                                trailing: Text('- ${currencyFmt.format(ex.amount)}', style: FontTokens.moneySmall.copyWith(color: ColorTokens.error, fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Botón Cerrar y Cuadrar Caja
                      CustomButton(
                        text: 'Cerrar y Cuadrar Caja',
                        icon: Icons.check_circle_outline,
                        onPressed: () => _openCloseShiftSheet(context, ref, shift),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),

          // Tab 2: Historial de Cierres
          _ShiftHistoryList(),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        border: Border.all(color: ColorTokens.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.textDim)),
          const SizedBox(height: 4),
          Text(value, style: FontTokens.moneySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _OpenShiftSheet extends ConsumerStatefulWidget {
  final String userName;
  final VoidCallback onSuccess;

  const _OpenShiftSheet({required this.userName, required this.onSuccess});

  @override
  ConsumerState<_OpenShiftSheet> createState() => _OpenShiftSheetState();
}

class _OpenShiftSheetState extends ConsumerState<_OpenShiftSheet> {
  final _amountCtrl = TextEditingController(text: '100000');
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousAmount();
  }

  void _loadPreviousAmount() async {
    final repo = ref.read(cashShiftRepositoryProvider);
    final prevAmount = await repo.getLastClosedShiftAmount();
    if (mounted) {
      setState(() {
        _amountCtrl.text = prevAmount.toInt().toString();
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final amount = double.tryParse(_amountCtrl.text) ?? -1;
    if (amount < 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(cashShiftRepositoryProvider);
      await repo.openShift(amount, widget.userName);
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir caja: $e'), backgroundColor: ColorTokens.error));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Responsable: ${widget.userName}', style: FontTokens.bodyMedium.copyWith(color: ColorTokens.textMuted)),
        const SizedBox(height: 12),
        CustomMoneyInput(
          label: 'Monto Base Inicial en Efectivo (Cierre Anterior)',
          hint: '100000',
          controller: _amountCtrl,
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Confirmar Apertura de Caja',
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final String shiftId;
  final VoidCallback onSuccess;

  const _AddExpenseSheet({required this.shiftId, required this.onSuccess});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit(WidgetRef ref) async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0 || _descCtrl.text.trim().isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(cashShiftRepositoryProvider);
      await repo.addExpense(widget.shiftId, _descCtrl.text.trim(), amount);
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar egreso: $e'), backgroundColor: ColorTokens.error));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (ctx, ref, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              label: 'Concepto / Descripción del Gasto',
              hint: 'Pago de transporte, bolsas, almuerzo…',
              controller: _descCtrl,
            ),
            const SizedBox(height: 12),
            CustomMoneyInput(
              label: 'Monto del Egreso',
              hint: '15000',
              controller: _amountCtrl,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Registrar Egreso',
              isLoading: _isSubmitting,
              onPressed: () => _submit(ref),
            ),
          ],
        );
      },
    );
  }
}

class _CloseShiftSheet extends StatefulWidget {
  final CashShift shift;
  final VoidCallback onSuccess;

  const _CloseShiftSheet({required this.shift, required this.onSuccess});

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  final _actualAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _actualAmountCtrl.text = widget.shift.computedExpected.toInt().toString();
  }

  @override
  void dispose() {
    _actualAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit(WidgetRef ref) async {
    final actual = double.tryParse(_actualAmountCtrl.text) ?? -1;
    if (actual < 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(cashShiftRepositoryProvider);
      await repo.closeShift(widget.shift.id, actual, _notesCtrl.text.trim());
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cerrar caja: $e'), backgroundColor: ColorTokens.error));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final actual = double.tryParse(_actualAmountCtrl.text) ?? 0;
    final diff = actual - widget.shift.computedExpected;

    return Consumer(
      builder: (ctx, ref, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceElevated,
                border: Border.all(color: ColorTokens.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('EFECTIVO ESPERADO', style: FontTokens.label),
                  Text(currencyFmt.format(widget.shift.computedExpected), style: FontTokens.moneyMedium.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CustomMoneyInput(
              label: 'Efectivo Físico Contado en Cajón',
              hint: '0',
              controller: _actualAmountCtrl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: diff == 0 ? ColorTokens.primary.withAlpha(20) : diff > 0 ? ColorTokens.secondary.withAlpha(20) : ColorTokens.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(diff == 0 ? 'CUADRE EXACTO' : diff > 0 ? 'SOBRANTE' : 'FALTANTE EN CAJA', style: FontTokens.label.copyWith(color: diff == 0 ? ColorTokens.primary : diff > 0 ? ColorTokens.secondary : ColorTokens.error)),
                  Text(currencyFmt.format(diff.abs()), style: FontTokens.moneySmall.copyWith(color: diff == 0 ? ColorTokens.primary : diff > 0 ? ColorTokens.secondary : ColorTokens.error, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Observaciones del Cierre',
              hint: 'Novedades, billetes deteriorados…',
              controller: _notesCtrl,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Confirmar Cierre de Caja',
              isLoading: _isSubmitting,
              onPressed: () => _submit(ref),
            ),
          ],
        );
      },
    );
  }
}

class _ShiftHistoryList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(cashShiftHistoryFutureProvider);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(cashShiftHistoryFutureProvider);
        await ref.read(cashShiftHistoryFutureProvider.future);
      },
      backgroundColor: Colors.white,
      color: ColorTokens.lightBrandPrimary,
      child: historyAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando historial de cierres...'),
        error: (err, stack) => ErrorState(
          title: 'Error al cargar cierres',
          message: err.toString(),
          onRetry: () => ref.invalidate(cashShiftHistoryFutureProvider),
        ),
        data: (shifts) {
          if (shifts.isEmpty) {
            return const EmptyState(
              title: 'Sin cierres finalizados',
              description: 'Aún no hay registros de cierres de caja finalizados.',
              icon: Icons.history,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shifts.length,
            separatorBuilder: (ctx, itemIndex) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final s = shifts[idx];
              final diff = s.difference ?? 0;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: BorderShadowTokens.shadowClayCard,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    CustomOverlays.showBottomSheet(
                      context: context,
                      title: 'Detalle & Ventas del Turno',
                      child: _ShiftSalesDetailSheet(shift: s),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 18, color: ColorTokens.lightBrandPrimary),
                                const SizedBox(width: 6),
                                Text('TURNO DE: ${s.userName.toUpperCase()}', style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: s.isOpen ? ColorTokens.lightBrandPrimary.withAlpha(20) : ColorTokens.lightTextSecondary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.isOpen ? 'EN VIVO' : 'CERRADO',
                                style: FontTokens.label.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: s.isOpen ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Apertura: ${dateFmt.format(s.openedAt.toLocal())}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                        if (s.closedAt != null) ...[
                          Text('Cierre: ${dateFmt.format(s.closedAt!.toLocal())}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Esperado: ${CurrencyUtils.format(s.expectedAmount)}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                            Text('Contado: ${CurrencyUtils.format(s.actualAmount ?? 0)}', style: FontTokens.bodySmall.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
                          ],
                        ),
                        if (diff != 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            diff > 0 ? 'Sobrante: +${CurrencyUtils.format(diff)}' : 'Faltante: ${CurrencyUtils.format(diff)}',
                            style: FontTokens.bodySmall.copyWith(
                              color: diff > 0 ? ColorTokens.statusSuccess : ColorTokens.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(Icons.touch_app_outlined, size: 14, color: ColorTokens.lightBrandPrimary),
                            const SizedBox(width: 4),
                            Text(
                              'Ver ventas de este turno',
                              style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const Icon(Icons.chevron_right, size: 16, color: ColorTokens.lightBrandPrimary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShiftSalesDetailSheet extends ConsumerWidget {
  final CashShift shift;
  const _ShiftSalesDetailSheet({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');

    final shiftSalesAsync = ref.watch(shiftSalesFutureProvider(shift));

    return shiftSalesAsync.when(
      loading: () => const LoadingSpinner(message: 'Cargando ventas del turno...'),
      error: (err, stack) => ErrorState(title: 'Error al cargar ventas', message: err.toString()),
      data: (sales) {
        final cashSalesTotal = sales
            .where((s) => s.paymentMethod.trim().toLowerCase() == 'efectivo')
            .fold(0.0, (sum, s) => sum + s.total);

        final transferSalesTotal = sales
            .where((s) => s.paymentMethod.trim().toLowerCase() != 'efectivo')
            .fold(0.0, (sum, s) => sum + s.total);

        final displayCashSales = shift.cashSales > 0 ? shift.cashSales : cashSalesTotal;
        final displayTransferSales = shift.transferSales > 0 ? shift.transferSales : transferSalesTotal;
        final expectedInCash = shift.initialAmount + displayCashSales - shift.totalExpenses;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ColorTokens.lightBgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TURNO DE: ${shift.userName.toUpperCase()}', style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: shift.isOpen ? ColorTokens.lightBrandPrimary.withAlpha(20) : ColorTokens.lightTextSecondary.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            shift.isOpen ? 'EN VIVO' : 'CERRADO',
                            style: FontTokens.label.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: shift.isOpen ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Apertura: ${dateFmt.format(shift.openedAt.toLocal())}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                    if (shift.closedAt != null)
                      Text('Cierre: ${dateFmt.format(shift.closedAt!.toLocal())}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Base Inicial: ${CurrencyUtils.format(shift.initialAmount)}', style: FontTokens.bodySmall),
                        Text('Ventas Efectivo: ${CurrencyUtils.format(displayCashSales)}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ventas Transf.: ${CurrencyUtils.format(displayTransferSales)}', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightBrandSecondary, fontWeight: FontWeight.bold)),
                        Text('Caja: ${CurrencyUtils.format(expectedInCash)}', style: FontTokens.bodySmall.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('REGISTRO DE VENTAS EN ESTE TURNO (${sales.length})', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (sales.isEmpty)
                const EmptyState(
                  title: 'Sin ventas registradas',
                  description: 'No se realizaron transacciones de venta durante el horario de este turno.',
                  icon: Icons.receipt_long_outlined,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final sale = sales[idx];
                  final itemsText = sale.items.map((i) => '${i.qty}× ${i.productName}').join(', ');
                  final hasReceiptImage = sale.receiptImageUrl != null && sale.receiptImageUrl!.trim().isNotEmpty;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: ColorTokens.lightBorderSubtle),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      onTap: () => ReceiptModal.show(context, sale),
                      title: Text(
                        itemsText.isNotEmpty ? itemsText : 'Venta Registrada',
                        style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${dateFmt.format(sale.createdAt.toLocal())} · ${sale.paymentMethod.toUpperCase()}',
                        style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyUtils.format(sale.total),
                            style: FontTokens.moneyMedium.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold),
                          ),
                          if (hasReceiptImage) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.visibility, color: ColorTokens.lightBrandPrimary, size: 20),
                              tooltip: 'Ver comprobante de transferencia',
                              onPressed: () => ImageViewerModal.show(
                                context,
                                imageUrl: sale.receiptImageUrl!.trim(),
                                title: 'Comprobante de Transferencia',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
}
