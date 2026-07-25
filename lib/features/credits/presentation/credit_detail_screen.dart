import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../core/design_system/widgets/custom_badges.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../core/design_system/widgets/custom_overlays.dart';
import '../../../core/design_system/widgets/custom_image_picker.dart';
import '../../../shared/widgets/installment_table.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/image_viewer_modal.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/models/credit.dart';
import '../../../core/utils/currency_formatter.dart';

class CreditDetailScreen extends ConsumerWidget {
  final String creditId;
  const CreditDetailScreen({super.key, required this.creditId});

  void _openPaymentSheet(BuildContext context, WidgetRef ref, Credit credit) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Registrar pago',
      child: _RegisterPaymentSheet(
        credit: credit,
        onSave: (updatedCredit) async {
          final repo = ref.read(creditRepositoryProvider);
          await repo.updateCredit(updatedCredit);
          ref.invalidate(creditsFutureProvider);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pago de cuota registrado exitosamente'),
                backgroundColor: ColorTokens.lightBrandPrimary,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsFutureProvider);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Crédito'),
      ),
      body: creditsAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando detalle de crédito...'),
        error: (err, stack) => ErrorState(
          title: 'Error al cargar crédito',
          message: err.toString(),
          onRetry: () => ref.invalidate(creditsFutureProvider),
        ),
        data: (credits) {
          final credit = credits.where((c) => c.id == creditId).firstOrNull;

          if (credit == null) {
            return const ErrorState(
              title: 'Crédito no encontrado',
              message: 'El crédito solicitado no existe o fue eliminado.',
            );
          }

          final st = credit.status;
          final pct = credit.progressPercentage;
          final paid = credit.totalPaid;
          final pending = credit.pendingBalance;
          final od = credit.overdueQuotasCount;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Cartilla Brand Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ColorTokens.lightBorderSubtle),
                    boxShadow: BorderShadowTokens.shadow3DCard,
                  ),
                  child: Row(
                    children: [
                      const AppLogo(size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALFA GAMA STORE',
                              style: FontTokens.bodyLarge.copyWith(
                                color: ColorTokens.lightTextPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Moda, Calidad y Estilo',
                              style: FontTokens.bodySmall.copyWith(
                                color: ColorTokens.lightTextSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('REGISTRO', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text(dateFmt.format(credit.startDate), style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card Datos del Cliente (Rediseñada)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: ColorTokens.lightBorderSubtle),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: BorderShadowTokens.shadowClayCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline, color: ColorTokens.lightBrandPrimary, size: 20),
                              const SizedBox(width: 6),
                              Text('DATOS DEL CLIENTE', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          StatusBadge(status: st),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('NOMBRE DEL TITULAR', style: FontTokens.label.copyWith(fontSize: 9, color: ColorTokens.lightTextSecondary)),
                                const SizedBox(height: 2),
                                Text(credit.clientName, style: FontTokens.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TELÉFONO', style: FontTokens.label.copyWith(fontSize: 9, color: ColorTokens.lightTextSecondary)),
                                const SizedBox(height: 2),
                                Text(credit.clientPhone, style: FontTokens.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Datos de Documento e Interés
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ColorTokens.lightBgSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ColorTokens.lightBorderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.badge_outlined, size: 16, color: ColorTokens.lightBrandPrimary),
                                const SizedBox(width: 6),
                                Text(
                                  credit.generalNotes.contains('Documento:')
                                      ? credit.generalNotes.split('|')[0].trim()
                                      : 'Documento: CC Registrada',
                                  style: FontTokens.bodySmall.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.percent_outlined, size: 16, color: ColorTokens.lightBrandSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  credit.generalNotes.contains('Interés:')
                                      ? 'Tasa: ${credit.generalNotes.split('Interés:')[1].trim()}'
                                      : 'Tasa: 0%',
                                  style: FontTokens.bodySmall.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightBrandSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (credit.clientAddress.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: ColorTokens.lightTextSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(credit.clientAddress, style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 16, color: ColorTokens.lightTextSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(credit.products, style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Resumen de la Cuenta
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ColorTokens.surface,
                    border: Border.all(color: ColorTokens.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RESUMEN DE LA CUENTA', style: FontTokens.label.copyWith(color: ColorTokens.secondary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile('TOTAL VENTA', CurrencyUtils.format(credit.totalSale), ColorTokens.text),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile('ABONADO', CurrencyUtils.format(paid), ColorTokens.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile('SALDO', CurrencyUtils.format(pending), ColorTokens.error),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Avance del pago', style: FontTokens.bodySmall),
                          Text('${pct.toStringAsFixed(1)}%', style: FontTokens.moneySmall.copyWith(color: st == 'mora' ? ColorTokens.warning : ColorTokens.primary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressBar(percentage: pct, color: st == 'mora' ? ColorTokens.warning : ColorTokens.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Términos del Crédito Grid
                Row(
                  children: [
                    Expanded(child: _buildTermTile('VALOR CUOTA', CurrencyUtils.format(credit.quotaValue))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTermTile('FRECUENCIA', credit.paymentFrequency.toUpperCase())),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTermTile('TOTAL CUOTAS', '${credit.totalQuotas}')),
                  ],
                ),
                const SizedBox(height: 12),

                // Alertas de Mora
                if (od > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: ColorTokens.errorDim,
                      border: Border.all(color: ColorTokens.error.withAlpha(60)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: ColorTokens.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$od cuota${od != 1 ? 's' : ''} vencida${od != 1 ? 's' : ''} sin pago',
                          style: FontTokens.bodyMedium.copyWith(color: ColorTokens.error, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Botón Registrar Pago
                if (st != 'finalizado') ...[
                  CustomButton(
                    text: 'Registrar pago',
                    icon: Icons.check_circle_outline,
                    onPressed: () => _openPaymentSheet(context, ref, credit),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tabla de Plan de Pagos
                InstallmentTable(
                  installments: credit.installments,
                  totalSale: credit.totalSale,
                ),
                const SizedBox(height: 20),

                // Sección: Comprobantes de Transferencia
                _buildTransferReceiptsSection(context, credit),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransferReceiptsSection(BuildContext context, Credit credit) {
    final receiptInsts = credit.installments
        .where((i) => i.receiptImageUrl != null && i.receiptImageUrl!.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: ColorTokens.lightBrandPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              'COMPROBANTES DE TRANSFERENCIA',
              style: FontTokens.label.copyWith(
                color: ColorTokens.lightBrandPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (receiptInsts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorTokens.lightBorderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: ColorTokens.lightTextSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay comprobantes de transferencia adjuntos para este crédito.',
                    style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: receiptInsts.length,
            separatorBuilder: (context, idx) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final inst = receiptInsts[idx];
              final dateStr = inst.paidDate != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(inst.paidDate!)
                  : DateFormat('dd/MM/yyyy').format(inst.dueDate);
              final clean = inst.receiptImageUrl!.trim();

              Widget imgWidget;
              if (clean.startsWith('data:image') || clean.length > 500) {
                try {
                  final base64Str = clean.contains(',') ? clean.split(',').last : clean;
                  final bytes = base64Decode(base64Str);
                  imgWidget = Image.memory(bytes, fit: BoxFit.cover, width: 52, height: 52);
                } catch (_) {
                  imgWidget = Container(width: 52, height: 52, color: ColorTokens.lightBgSecondary, child: const Icon(Icons.broken_image_outlined, color: ColorTokens.lightTextSecondary));
                }
              } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
                imgWidget = Image.network(clean, fit: BoxFit.cover, width: 52, height: 52, errorBuilder: (c, e, st) => Container(width: 52, height: 52, color: ColorTokens.lightBgSecondary, child: const Icon(Icons.broken_image_outlined, color: ColorTokens.lightTextSecondary)));
              } else {
                final f = File(clean);
                if (f.existsSync()) {
                  imgWidget = Image.file(f, fit: BoxFit.cover, width: 52, height: 52);
                } else {
                  imgWidget = Container(width: 52, height: 52, color: ColorTokens.lightBgSecondary, child: const Icon(Icons.receipt_long_outlined, color: ColorTokens.lightTextSecondary));
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                  boxShadow: BorderShadowTokens.shadowClayCard,
                ),
                child: Row(
                  children: [
                    // Miniatura en la izquierda
                    GestureDetector(
                      onTap: () => ImageViewerModal.show(context, imageUrl: clean, title: 'Comprobante Cuota #${inst.quotaNumber}'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: imgWidget,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Información central: Fecha, Hora y Cuota
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cuota #${inst.quotaNumber} · ${CurrencyUtils.format(inst.paidAmount > 0 ? inst.paidAmount : inst.quotaValue)}',
                            style: FontTokens.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ColorTokens.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: FontTokens.bodySmall.copyWith(
                              fontSize: 11,
                              color: ColorTokens.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (inst.paymentMethod.isNotEmpty ? inst.paymentMethod : 'TRANSFERENCIA').toUpperCase(),
                            style: FontTokens.label.copyWith(
                              fontSize: 9,
                              color: ColorTokens.lightBrandPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Ícono Ojo en la derecha para ver imagen completa
                    IconButton(
                      icon: const Icon(Icons.visibility, color: ColorTokens.lightBrandPrimary, size: 22),
                      tooltip: 'Ver comprobante completo',
                      onPressed: () => ImageViewerModal.show(context, imageUrl: clean, title: 'Comprobante Cuota #${inst.quotaNumber}'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FontTokens.label.copyWith(fontSize: 8)),
          const SizedBox(height: 4),
          Text(value, style: FontTokens.moneySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTermTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        border: Border.all(color: ColorTokens.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FontTokens.label.copyWith(fontSize: 8)),
          const SizedBox(height: 4),
          Text(value, style: FontTokens.moneySmall.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RegisterPaymentSheet extends StatefulWidget {
  final Credit credit;
  final ValueChanged<Credit> onSave;

  const _RegisterPaymentSheet({required this.credit, required this.onSave});

  @override
  State<_RegisterPaymentSheet> createState() => _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState extends State<_RegisterPaymentSheet> {
  late int _selectedQuotaIdx;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  String _paymentMethod = 'efectivo';
  String? _receiptImageUrl;

  @override
  void initState() {
    super.initState();
    // Default to the first unpaid quota
    _selectedQuotaIdx = widget.credit.installments.indexWhere((i) => i.status != 'pagado');
    if (_selectedQuotaIdx < 0) _selectedQuotaIdx = 0;
    
    final initialQuotaValue = widget.credit.installments[_selectedQuotaIdx].quotaValue;
    _amountCtrl = TextEditingController(text: initialQuotaValue.toInt().toString());
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  void _submitPayment() async {
    if (_isSubmitting) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0 || _selectedQuotaIdx < 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final updatedInstallments = List<CreditInstallment>.from(widget.credit.installments);
      final targetInst = updatedInstallments[_selectedQuotaIdx];

      updatedInstallments[_selectedQuotaIdx] = targetInst.copyWith(
        paidAmount: targetInst.paidAmount + amount,
        paidDate: DateTime.now(),
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.trim(),
        receiptImageUrl: _paymentMethod == 'transferencia' ? _receiptImageUrl : null,
      );

      final updatedCredit = widget.credit.copyWith(installments: updatedInstallments);
      widget.onSave(updatedCredit);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final pendingInsts = widget.credit.installments.where((i) => i.status != 'pagado').toList();

    if (pendingInsts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: ColorTokens.primary, size: 48),
            const SizedBox(height: 12),
            Text('Crédito Finalizado', style: FontTokens.h2),
            const SizedBox(height: 16),
            CustomButton(text: 'Cerrar', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    final currentAmount = double.tryParse(_amountCtrl.text) ?? 0;
    final newPendingBalance = (widget.credit.pendingBalance - currentAmount).clamp(0.0, 999999999.0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECCIONA LA CUOTA A PAGAR', style: FontTokens.label),
          const SizedBox(height: 8),
          
          // List of Unpaid Installment Buttons
          Column(
            children: widget.credit.installments.asMap().entries.map((entry) {
              final idx = entry.key;
              final inst = entry.value;
              if (inst.status == 'pagado') return const SizedBox();

              final isSelected = _selectedQuotaIdx == idx;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedQuotaIdx = idx;
                      _amountCtrl.text = inst.quotaValue.toInt().toString();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? ColorTokens.secondary.withAlpha(30) : ColorTokens.surfaceElevated,
                      border: Border.all(color: isSelected ? ColorTokens.secondary : ColorTokens.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cuota ${inst.quotaNumber}', style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            Text(dateFmt.format(inst.dueDate), style: FontTokens.label.copyWith(color: inst.status == 'vencido' ? ColorTokens.error : ColorTokens.textDim)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(currencyFmt.format(inst.quotaValue), style: FontTokens.moneySmall),
                            const SizedBox(height: 2),
                            InstStatusBadge(status: inst.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          CustomMoneyInput(
            label: 'Valor del Abono',
            hint: '250000',
            controller: _amountCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          Text('MÉTODO DE PAGO', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: ['efectivo', 'transferencia'].map((m) {
              final isSelected = _paymentMethod == m;
              Color color = m == 'efectivo'
                  ? ColorTokens.lightBrandPrimary
                  : ColorTokens.lightBrandSecondary;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _paymentMethod = m;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected ? color.withAlpha(20) : Colors.white,
                      side: BorderSide(color: isSelected ? color : ColorTokens.lightBorderSubtle, width: isSelected ? 2 : 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      m == 'efectivo' ? 'EFECTIVO' : 'TRANSFERENCIA',
                      style: FontTokens.label.copyWith(
                        color: isSelected ? color : ColorTokens.lightTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_paymentMethod == 'transferencia') ...[
            const SizedBox(height: 14),
            CustomImagePicker(
              initialImageUrl: _receiptImageUrl,
              label: 'Comprobante de Transferencia (Opcional)',
              onImageSelected: (url) {
                setState(() {
                  _receiptImageUrl = url;
                });
              },
            ),
          ],

          const SizedBox(height: 14),
          CustomTextField(
            label: 'Observaciones',
            hint: 'Número de referencia, comprobante…',
            controller: _notesCtrl,
          ),
          const SizedBox(height: 16),

          // Summary Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorTokens.secondary.withAlpha(20),
              border: Border.all(color: ColorTokens.secondary.withAlpha(60)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NUEVO SALDO PENDIENTE', style: FontTokens.label),
                Text(
                  CurrencyUtils.format(newPendingBalance),
                  style: FontTokens.moneyMedium.copyWith(color: ColorTokens.secondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CustomButton(
            text: 'Confirmar pago · ${CurrencyUtils.format(currentAmount)}',
            isLoading: _isSubmitting,
            onPressed: currentAmount > 0 ? _submitPayment : null,
          ),
        ],
      ),
    );
  }
}
