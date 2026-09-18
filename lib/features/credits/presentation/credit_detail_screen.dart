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
import '../../../shared/models/customer.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/barcode_scanner_modal.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  void _openExtraChargeSheet(BuildContext context, WidgetRef ref, Credit credit) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Agregar cargo extra al crédito',
      child: _AddExtraChargeSheet(
        credit: credit,
        onSave: (charge, updatedCredit) async {
          final repo = ref.read(creditRepositoryProvider);
          await repo.addExtraCharge(credit.id, charge, updatedCredit);
          ref.invalidate(creditsFutureProvider);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cargo de ${CurrencyUtils.format(charge.amount)} aplicado exitosamente.'),
                backgroundColor: ColorTokens.lightBrandPrimary,
              ),
            );
          }
        },
      ),
    );
  }

  void _openEditCreditSheet(BuildContext context, WidgetRef ref, Credit credit) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Editar crédito completo',
      child: _EditCreditSheet(
        credit: credit,
        onSave: (updatedCredit) async {
          final repo = ref.read(creditRepositoryProvider);
          await repo.updateCredit(updatedCredit);
          ref.invalidate(creditsFutureProvider);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Crédito actualizado exitosamente'),
                backgroundColor: ColorTokens.lightBrandPrimary,
              ),
            );
          }
        },
        onDelete: (id) async {
          final repo = ref.read(creditRepositoryProvider);
          await repo.deleteCredit(id);
          ref.invalidate(creditsFutureProvider);
          if (context.mounted) {
            Navigator.pop(context); // Cierra bottom sheet
            Navigator.pop(context); // Vuelve a la lista de créditos
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Crédito eliminado exitosamente'),
                backgroundColor: ColorTokens.error,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _shareCreditPDF(BuildContext context, Credit credit) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy');
    final cf = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    double runningBal = credit.totalSale.toDouble();
    final List<Map<String, dynamic>> rows = [];
    for (var inst in credit.installments) {
      runningBal -= inst.paidAmount;
      rows.add({
        'inst': inst,
        'balance': runningBal.clamp(0.0, double.infinity),
      });
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Cabecera institucional
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0x0D1A33),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ALFA GAMA STORE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Moda, Calidad y Estilo',
                        style: pw.TextStyle(
                          color: PdfColors.grey300,
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'EXTRACTO DE CUENTA DE CRÉDITO',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Fecha Emisión: ${df.format(DateTime.now())}',
                        style: pw.TextStyle(
                          color: PdfColors.grey300,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // Título Datos del Cliente
            pw.Text(
              'DATOS DEL CLIENTE',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0x0D1A33),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),

            // Caja Datos Cliente
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'NOMBRE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                              pw.TextSpan(text: credit.clientName, style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'CC/NIT: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                              pw.TextSpan(
                                text: credit.generalNotes.contains('Documento:') 
                                  ? (credit.generalNotes.split('|')[0].replaceAll('Documento:', '').trim().isNotEmpty 
                                      ? credit.generalNotes.split('|')[0].replaceAll('Documento:', '').trim() 
                                      : '-')
                                  : '-', 
                                style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'TELÉFONO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                              pw.TextSpan(text: credit.clientPhone.isNotEmpty ? credit.clientPhone : '-', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'REGISTRO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                              pw.TextSpan(text: df.format(credit.startDate), style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (credit.clientAddress.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(text: 'DIRECCIÓN: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                          pw.TextSpan(text: credit.clientAddress, style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                        ],
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 6),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'PRODUCTO(S): ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                        pw.TextSpan(text: credit.products, style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // Resumen de la Cuenta
            pw.Text(
              'RESUMEN DE LA CUENTA',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0x0D1A33),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),

            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    color: PdfColors.grey100,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL VENTA', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(cf.format(credit.totalSale), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    color: const PdfColor.fromInt(0xE6F8F0),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ABONADO', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0x00A854), fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(cf.format(credit.totalPaid), style: pw.TextStyle(fontSize: 12, color: const PdfColor.fromInt(0x00A854), fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    color: const PdfColor.fromInt(0xFFF0F0),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SALDO PENDIENTE', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xCC3333), fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(cf.format(credit.pendingBalance), style: pw.TextStyle(fontSize: 12, color: const PdfColor.fromInt(0xCC3333), fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Términos del Crédito Text
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Valor Cuota: ${cf.format(credit.quotaValue)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Frecuencia: ${credit.paymentFrequency.toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Total Cuotas: ${credit.totalQuotas}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Progreso: ${credit.progressPercentage.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 15),

            // Historial de Cargos Extras en el PDF si existen
            if (credit.charges.isNotEmpty) ...[
              pw.Text(
                'HISTORIAL DE CARGOS Y RECARGOS ADICIONALES',
                style: pw.TextStyle(
                  color: const PdfColor.fromInt(0x0D1A33),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0x0D1A33)),
                    children: [
                      for (var h in ['Fecha', 'Concepto / Motivo', 'Método de Aplicación', 'Valor'])
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  for (var ch in credit.charges)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(df.format(ch.createdAt), style: const pw.TextStyle(fontSize: 7)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(ch.concept, style: const pw.TextStyle(fontSize: 7)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            ch.distributionMethod == 'add_installment'
                                ? 'Nueva cuota al final'
                                : ch.distributionMethod == 'next_installment'
                                    ? 'Cargado a próxima cuota'
                                    : 'Repartido en cuotas',
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cf.format(ch.amount), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
            ],

            // Título Plan de Pagos
            pw.Text(
              'PLAN DE AMORTIZACIÓN Y CUOTAS',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0x0D1A33),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),

            // Tabla Plan de Pagos
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0x0D1A33),
                  ),
                  children: [
                    for (var header in ['N°', 'Fecha', 'Cuota', 'Abono', 'Saldo', 'Estado', 'Obs.'])
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          header,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                for (var r in rows)
                  () {
                    final inst = r['inst'] as CreditInstallment;
                    final isFullyPaid = credit.pendingBalance <= 0;
                    final statusKey = isFullyPaid ? 'pagado' : inst.status;
                    final statusLabel = statusKey.toUpperCase();
                    final statusColor = statusKey == 'pagado' 
                        ? PdfColors.green700 
                        : (statusKey == 'parcial' 
                            ? PdfColors.orange700 
                            : (statusKey == 'vencido' ? PdfColors.red700 : PdfColors.grey700));

                    final obsText = inst.paymentMethod.isNotEmpty 
                        ? inst.paymentMethod 
                        : (inst.notes.isNotEmpty ? inst.notes : '-');

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: inst.quotaNumber % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(inst.quotaNumber.toString(), style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(df.format(inst.dueDate), style: const pw.TextStyle(fontSize: 7.5)),
                              if (inst.paidDate != null && inst.paidAmount > 0)
                                pw.Text('Pagó: ${df.format(inst.paidDate!)}', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.green800)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cf.format(inst.quotaValue), style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(inst.paidAmount > 0 ? cf.format(inst.paidAmount) : '-', style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cf.format(r['balance']), style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            statusLabel, 
                            style: pw.TextStyle(
                              fontSize: 7, 
                              fontWeight: pw.FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(obsText, style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                      ],
                    );
                  }(),
              ],
            ),
            
            // Observaciones Generales
            if (credit.generalNotes.isNotEmpty) ...[
              pw.SizedBox(height: 15),
              pw.Text(
                'OBSERVACIONES GENERALES',
                style: pw.TextStyle(
                  color: const PdfColor.fromInt(0x0D1A33),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                credit.generalNotes,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '"Tu estilo, nuestra pasión"',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey400),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
                ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final filename = 'Extracto_Credito_${credit.clientName.replaceAll(RegExp(r'\s+'), '_')}.pdf';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsFutureProvider);
    final authState = ref.watch(authProvider);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Crédito'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: ColorTokens.lightBrandPrimary),
            tooltip: 'Editar crédito completo',
            onPressed: () {
              final credit = creditsAsync.value?.where((c) => c.id == creditId).firstOrNull;
              if (credit != null) {
                _openEditCreditSheet(context, ref, credit);
              }
            },
          ),
        ],
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

                // Resumen de la Cuenta & Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('RESUMEN DE CUENTA', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    StatusBadge(status: st),
                  ],
                ),
                const SizedBox(height: 8),

                // Tarjeta 3 Columnas: Total / Abonado / Saldo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ColorTokens.lightBorderSubtle),
                    boxShadow: BorderShadowTokens.shadowClayCard,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              'TOTAL VENTA',
                              CurrencyUtils.format(credit.totalSale),
                              ColorTokens.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile(
                              'ABONADO',
                              CurrencyUtils.format(paid),
                              ColorTokens.lightBrandPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile(
                              'SALDO',
                              CurrencyUtils.format(pending),
                              pending > 0 ? ColorTokens.error : ColorTokens.lightBrandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Barra de Progreso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Avance del pago', style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary)),
                          Text('${pct.toStringAsFixed(1)}%', style: FontTokens.bodySmall.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightBrandPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressBar(
                        percentage: pct,
                        color: st == 'mora' ? ColorTokens.warning : ColorTokens.lightBrandPrimary,
                      ),
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

                // Botones de Acción (Registrar Pago y Agregar Cargo Extra)
                if (st != 'finalizado') ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: CustomButton(
                          text: 'Registrar pago',
                          icon: Icons.check_circle_outline,
                          onPressed: () => _openPaymentSheet(context, ref, credit),
                        ),
                      ),
                      if (authState.isAdmin) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: CustomButton(
                            text: 'Cargo Extra',
                            icon: Icons.add_card_outlined,
                            isSecondary: true,
                            onPressed: () => _openExtraChargeSheet(context, ref, credit),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Botón Compartir Extracto PDF
                CustomButton(
                  text: 'Compartir Extracto (PDF)',
                  icon: Icons.share_outlined,
                  isSecondary: true,
                  onPressed: () => _shareCreditPDF(context, credit),
                ),
                const SizedBox(height: 16),

                // Historial de Cargos Extras si existen
                if (credit.charges.isNotEmpty) ...[
                  _buildExtraChargesSection(context, credit),
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

  Widget _buildExtraChargesSection(BuildContext context, Credit credit) {
    final df = DateFormat('dd/MM/yyyy hh:mm a');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorTokens.lightBorderSubtle),
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
                  const Icon(Icons.receipt_long_outlined, color: ColorTokens.lightBrandPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CARGOS Y RECARGOS APLICADOS',
                    style: FontTokens.label.copyWith(
                      color: ColorTokens.lightBrandPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorTokens.lightBrandPrimary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${credit.charges.length} cargo${credit.charges.length > 1 ? 's' : ''}',
                  style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: credit.charges.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final ch = credit.charges[idx];
              final String methodLabel = ch.distributionMethod == 'add_installment'
                  ? 'Nueva cuota al final'
                  : ch.distributionMethod == 'next_installment'
                      ? 'Carga en próxima cuota'
                      : 'Repartido en cuotas';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorTokens.lightBgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorTokens.lightBorderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ColorTokens.lightBorderSubtle),
                      ),
                      child: const Icon(Icons.add_shopping_cart_rounded, color: ColorTokens.lightBrandPrimary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.concept,
                            style: FontTokens.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ColorTokens.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${df.format(ch.createdAt)} · Por ${ch.createdBy}',
                            style: FontTokens.bodySmall.copyWith(fontSize: 10, color: ColorTokens.lightTextSecondary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ColorTokens.lightBrandSecondary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              methodLabel,
                              style: FontTokens.label.copyWith(fontSize: 9, color: ColorTokens.lightBrandSecondary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (ch.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Nota: ${ch.notes}',
                              style: FontTokens.bodySmall.copyWith(fontSize: 11, fontStyle: FontStyle.italic, color: ColorTokens.lightTextSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '+${CurrencyUtils.format(ch.amount)}',
                      style: FontTokens.moneyMedium.copyWith(
                        color: ColorTokens.lightBrandPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
  DateTime _selectedPaymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default to the first unpaid quota
    _selectedQuotaIdx = widget.credit.installments.indexWhere((i) => i.status != 'pagado');
    if (_selectedQuotaIdx < 0) _selectedQuotaIdx = 0;
    
    final initialQuotaValue = widget.credit.installments[_selectedQuotaIdx].quotaValue;
    _amountCtrl = TextEditingController(text: initialQuotaValue.toInt().toString());
    _notesCtrl = TextEditingController();
    _selectedPaymentDate = DateTime.now();
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
        paidDate: _selectedPaymentDate,
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

          // Selector de Fecha Real de Pago
          Text(
            'FECHA EN QUE SE REALIZÓ EL PAGO',
            style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedPaymentDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: ColorTokens.lightBrandPrimary,
                        onPrimary: Colors.white,
                        onSurface: ColorTokens.lightTextPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedPaymentDate = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    DateTime.now().hour,
                    DateTime.now().minute,
                    DateTime.now().second,
                  );
                });
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ColorTokens.lightBorderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: ColorTokens.lightBrandPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFmt.format(_selectedPaymentDate),
                          style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Toca para cambiar la fecha si pagó antes o después',
                          style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined, size: 18, color: ColorTokens.lightTextSecondary),
                ],
              ),
            ),
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

class _AddExtraChargeSheet extends StatefulWidget {
  final Credit credit;
  final Function(CreditCharge charge, Credit updatedCredit) onSave;

  const _AddExtraChargeSheet({
    required this.credit,
    required this.onSave,
  });

  @override
  State<_AddExtraChargeSheet> createState() => _AddExtraChargeSheetState();
}

class _AddExtraChargeSheetState extends State<_AddExtraChargeSheet> {
  final TextEditingController _conceptCtrl = TextEditingController(text: 'Recargo por mora');
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String _selectedMethod = 'distribute_remaining'; // 'distribute_remaining' | 'add_installment' | 'next_installment'
  bool _isSubmitting = false;

  final List<String> _quickConcepts = [
    'Recargo por mora',
    'Prenda / Producto extra',
    'Flete / Envío',
    'Ajuste administrativo',
    'Otro motivo',
  ];

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submitCharge() {
    if (_isSubmitting) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    final concept = _conceptCtrl.text.trim();

    if (amount <= 0 || concept.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final newCharge = CreditCharge(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        creditId: widget.credit.id,
        concept: concept,
        amount: amount,
        distributionMethod: _selectedMethod,
        createdAt: DateTime.now(),
        createdBy: 'Administrador',
        notes: _notesCtrl.text.trim(),
      );

      final updatedCredit = widget.credit.applyExtraCharge(charge: newCharge);
      widget.onSave(newCharge, updatedCredit);
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
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    final pendingInsts = widget.credit.installments.where((i) => i.status != 'pagado').toList();
    final dateFmt = DateFormat('dd/MM/yyyy');

    final daysStep = widget.credit.paymentFrequency == 'diario'
        ? 1
        : widget.credit.paymentFrequency == 'quincenal'
            ? 15
            : widget.credit.paymentFrequency == 'mensual'
                ? 30
                : 7;

    final lastDate = widget.credit.installments.isNotEmpty
        ? widget.credit.installments.last.dueDate
        : widget.credit.startDate;
    final newInstallmentDate = lastDate.add(Duration(days: daysStep));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Informativo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorTokens.lightBrandPrimary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorTokens.lightBrandPrimary.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: ColorTokens.lightBrandPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este cargo extra aumentará la deuda total del crédito y se distribuirá en el plan de pagos según tu elección.',
                    style: FontTokens.bodySmall.copyWith(
                      color: ColorTokens.lightBrandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selector de Motivos Rápidos
          Text('MOTIVO / CONCEPTO DEL CARGO', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickConcepts.map((c) {
              final isSelected = _conceptCtrl.text.trim() == (c == 'Otro motivo' ? '' : c);
              return ChoiceChip(
                label: Text(c),
                selected: isSelected,
                selectedColor: ColorTokens.lightBrandPrimary.withAlpha(30),
                backgroundColor: Colors.white,
                labelStyle: FontTokens.bodySmall.copyWith(
                  color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle,
                ),
                onSelected: (val) {
                  setState(() {
                    if (c == 'Otro motivo') {
                      _conceptCtrl.text = '';
                    } else {
                      _conceptCtrl.text = c;
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Campo de Concepto Libre
          CustomTextField(
            label: 'Concepto Personalizado',
            hint: 'Ej: Recargo por mora, Prenda extra: Blusa Seda',
            controller: _conceptCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Campo de Monto
          CustomMoneyInput(
            label: 'Valor del Cargo Extra (\$ COP)',
            hint: '50000',
            controller: _amountCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),

          // Métodos de Distribución con Explicación Detallada
          Text(
            '¿CÓMO DESEAS APLICAR ESTE CARGO EN LAS CUOTAS?',
            style: FontTokens.label.copyWith(
              color: ColorTokens.lightBrandPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Elige uno de los 3 métodos para saber exactamente cómo se recalculará el crédito:',
            style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
          ),
          const SizedBox(height: 12),

          // Método 1: Prorrateo en cuotas pendientes
          _buildMethodCard(
            methodKey: 'distribute_remaining',
            title: '1. Repartir entre cuotas pendientes',
            badgeText: 'Recomendado',
            icon: Icons.call_split_rounded,
            explanation: 'Divide el recargo en partes iguales entre las cuotas no pagadas. Mantiene exactamente el mismo plazo y número de cuotas del crédito.',
            simulationText: amount > 0 && pendingInsts.isNotEmpty
                ? '⚡ Simulación: Cada una de las ${pendingInsts.length} cuotas pendientes aumentará en +${CurrencyUtils.format(amount / pendingInsts.length)}.'
                : null,
          ),
          const SizedBox(height: 8),

          // Método 2: Nueva cuota al final
          _buildMethodCard(
            methodKey: 'add_installment',
            title: '2. Crear nueva cuota al final',
            badgeText: 'Alarga Plazo',
            icon: Icons.add_circle_outline_rounded,
            explanation: 'Conserva el valor de las cuotas actuales intacto y añade una cuota adicional (Cuota #${widget.credit.installments.length + 1}) al final del crédito.',
            simulationText: amount > 0
                ? '⚡ Simulación: Se creará la Cuota #${widget.credit.installments.length + 1} por ${CurrencyUtils.format(amount)} para la fecha ${dateFmt.format(newInstallmentDate)}.'
                : null,
          ),
          const SizedBox(height: 8),

          // Método 3: Sumar a la siguiente cuota inmediata
          _buildMethodCard(
            methodKey: 'next_installment',
            title: '3. Cargar a la próxima cuota a vencer',
            badgeText: 'Inmediato',
            icon: Icons.arrow_forward_rounded,
            explanation: 'Carga el 100% del recargo únicamente a la siguiente cuota más cercana por vencer. Las cuotas posteriores no sufren ningún cambio.',
            simulationText: amount > 0 && pendingInsts.isNotEmpty
                ? '⚡ Simulación: La Cuota #${pendingInsts.first.quotaNumber} (${dateFmt.format(pendingInsts.first.dueDate)}) pasará de ${CurrencyUtils.format(pendingInsts.first.quotaValue)} a ${CurrencyUtils.format(pendingInsts.first.quotaValue + amount)}.'
                : null,
          ),
          const SizedBox(height: 16),

          // Observaciones Opcionales
          CustomTextField(
            label: 'Observaciones / Notas del Recargo (Opcional)',
            hint: 'Motivo específico, número de autorización...',
            controller: _notesCtrl,
          ),
          const SizedBox(height: 16),

          // Resumen de Impacto en Balance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColorTokens.lightBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorTokens.lightBorderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL DEL CRÉDITO:', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary)),
                    Text(
                      '${CurrencyUtils.format(widget.credit.totalSale)} ➔ ${CurrencyUtils.format(widget.credit.totalSale + amount)}',
                      style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('NUEVO SALDO PENDIENTE:', style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyUtils.format(widget.credit.pendingBalance + amount),
                      style: FontTokens.moneyMedium.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Botón de Aplicar Cargo
          CustomButton(
            text: amount > 0 ? 'Aplicar cargo · ${CurrencyUtils.format(amount)}' : 'Ingresa el monto del cargo',
            icon: Icons.check_circle_outline,
            isLoading: _isSubmitting,
            onPressed: amount > 0 && _conceptCtrl.text.trim().isNotEmpty ? _submitCharge : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String methodKey,
    required String title,
    required String badgeText,
    required IconData icon,
    required String explanation,
    String? simulationText,
  }) {
    final isSelected = _selectedMethod == methodKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = methodKey;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? ColorTokens.lightBrandPrimary.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? BorderShadowTokens.shadow3DCard : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: FontTokens.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightBgSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: FontTokens.label.copyWith(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : ColorTokens.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              explanation,
              style: FontTokens.bodySmall.copyWith(
                fontSize: 11.5,
                color: ColorTokens.lightTextSecondary,
                height: 1.3,
              ),
            ),
            if (simulationText != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? ColorTokens.lightBrandPrimary.withAlpha(20) : ColorTokens.lightBgSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  simulationText,
                  style: FontTokens.bodySmall.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditCreditSheet extends ConsumerStatefulWidget {
  final Credit credit;
  final ValueChanged<Credit> onSave;
  final ValueChanged<String> onDelete;

  const _EditCreditSheet({
    required this.credit,
    required this.onSave,
    required this.onDelete,
  });

  @override
  ConsumerState<_EditCreditSheet> createState() => _EditCreditSheetState();
}

class _EditCreditSheetState extends ConsumerState<_EditCreditSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _docIdCtrl;
  late TextEditingController _productsCtrl;
  late TextEditingController _totalSaleCtrl;
  late TextEditingController _totalQuotasCtrl;
  late TextEditingController _customInterestCtrl;
  late TextEditingController _customQuotaCtrl;
  late TextEditingController _extraNotesCtrl;

  String _docType = 'CC';
  String _frequency = 'mensual';
  DateTime _startDate = DateTime.now();

  bool _isSubmitting = false;

  String _customerQuery = '';
  String _productQuery = '';
  bool _showCustomerResults = false;
  bool _showProductResults = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.credit.startDate;
    _frequency = widget.credit.paymentFrequency;

    _nameCtrl = TextEditingController(text: widget.credit.clientName);
    _phoneCtrl = TextEditingController(text: widget.credit.clientPhone);
    _addressCtrl = TextEditingController(text: widget.credit.clientAddress);
    _productsCtrl = TextEditingController(text: widget.credit.products);
    _totalQuotasCtrl = TextEditingController(text: widget.credit.totalQuotas.toString());
    _customQuotaCtrl = TextEditingController(text: widget.credit.quotaValue.toInt().toString());

    // Parse Documento, Interés y notas adicionales desde generalNotes
    _parseNotes(widget.credit.generalNotes);

    _docIdCtrl = TextEditingController(text: _parsedDocId);
    _customInterestCtrl = TextEditingController(text: _parsedInterestRate > 0 ? _parsedInterestRate.toStringAsFixed(1) : '');
    _extraNotesCtrl = TextEditingController(text: _parsedExtraNotes);

    // Calcular venta base sin interés
    double baseSale = widget.credit.totalSale;
    if (_parsedInterestRate > 0) {
      baseSale = widget.credit.totalSale / (1 + (_parsedInterestRate / 100));
    }
    _totalSaleCtrl = TextEditingController(text: baseSale.toInt().toString());
  }

  String _parsedDocId = '';
  double _parsedInterestRate = 0.0;
  String _parsedExtraNotes = '';

  void _parseNotes(String notes) {
    if (notes.isEmpty) return;

    if (notes.contains('Documento:')) {
      final afterDoc = notes.split('Documento:')[1].split('|')[0].trim();
      final tokens = afterDoc.split(' ');
      if (tokens.isNotEmpty) {
        if (['CC', 'NIT', 'CE', 'Pasaporte', 'PAS'].contains(tokens[0])) {
          _docType = tokens[0] == 'PAS' ? 'Pasaporte' : tokens[0];
          if (tokens.length > 1) {
            _parsedDocId = tokens.sublist(1).join(' ').trim();
          }
        } else {
          _parsedDocId = afterDoc;
        }
      }
    }

    if (notes.contains('Interés:')) {
      final afterInt = notes.split('Interés:')[1].split('|')[0].replaceAll('%', '').trim();
      _parsedInterestRate = double.tryParse(afterInt) ?? 0.0;
    }

    final parts = notes.split('|').map((p) => p.trim()).where((p) => !p.startsWith('Documento:') && !p.startsWith('Interés:')).toList();
    if (parts.isNotEmpty) {
      _parsedExtraNotes = parts.join(' | ');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _docIdCtrl.dispose();
    _productsCtrl.dispose();
    _totalSaleCtrl.dispose();
    _totalQuotasCtrl.dispose();
    _customInterestCtrl.dispose();
    _customQuotaCtrl.dispose();
    _extraNotesCtrl.dispose();
    super.dispose();
  }

  double get _baseSale => double.tryParse(_totalSaleCtrl.text) ?? 0;
  double get _interestRate => double.tryParse(_customInterestCtrl.text) ?? 0;
  double get _interestAmount => _baseSale * (_interestRate / 100);
  double get _totalWithInterest => _baseSale + _interestAmount;

  double get _quotaValue {
    final manualQuota = double.tryParse(_customQuotaCtrl.text);
    if (manualQuota != null && manualQuota > 0) return manualQuota;

    final quotas = int.tryParse(_totalQuotasCtrl.text) ?? 0;
    if (_totalWithInterest > 0 && quotas > 0) {
      return (_totalWithInterest / quotas).ceilToDouble();
    }
    return 0;
  }

  void _handleSave() {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final totalQuotas = int.tryParse(_totalQuotasCtrl.text) ?? widget.credit.totalQuotas;
    final productText = _productsCtrl.text.trim();
    final customerText = _nameCtrl.text.trim();

    // Reconstruir generalNotes con Documento, Interés y notas adicionales
    final docString = _docIdCtrl.text.trim().isNotEmpty ? 'Documento: $_docType ${_docIdCtrl.text.trim()}' : '';
    final intString = _interestRate > 0 ? 'Interés: ${_interestRate.toStringAsFixed(1)}%' : '';
    final extraString = _extraNotesCtrl.text.trim();
    final notesList = [docString, intString, extraString].where((s) => s.isNotEmpty).toList();
    final formattedGeneralNotes = notesList.join(' | ');

    // Recalcular cuotas si cambió el total, la frecuencia o la cantidad de cuotas
    List<CreditInstallment> newInstallments;
    if (totalQuotas != widget.credit.totalQuotas || _frequency != widget.credit.paymentFrequency || _totalWithInterest != widget.credit.totalSale) {
      newInstallments = Credit.generateInstallments(
        _startDate,
        _frequency,
        totalQuotas,
        _quotaValue,
      );
      // Preservar abonos de cuotas que ya fueron pagadas
      for (int i = 0; i < newInstallments.length && i < widget.credit.installments.length; i++) {
        final old = widget.credit.installments[i];
        if (old.paidAmount > 0) {
          newInstallments[i] = newInstallments[i].copyWith(
            paidAmount: old.paidAmount,
            paidDate: old.paidDate,
            paymentMethod: old.paymentMethod,
            notes: old.notes,
            receiptImageUrl: old.receiptImageUrl,
          );
        }
      }
    } else {
      newInstallments = widget.credit.installments.map((i) {
        return i.copyWith(quotaValue: _quotaValue);
      }).toList();
    }

    final updated = widget.credit.copyWith(
      clientName: customerText,
      clientPhone: _phoneCtrl.text.trim(),
      clientAddress: _addressCtrl.text.trim(),
      products: productText,
      totalSale: _totalWithInterest,
      paymentFrequency: _frequency,
      totalQuotas: totalQuotas,
      quotaValue: _quotaValue,
      installments: newInstallments,
      generalNotes: formattedGeneralNotes,
    );

    widget.onSave(updated);
  }

  void _handleDelete() {
    final bool isFullyPaid = widget.credit.status == 'finalizado' || widget.credit.pendingBalance <= 0 || widget.credit.totalPaid >= widget.credit.totalSale;

    if (!isFullyPaid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.lock_outline, color: ColorTokens.warning),
              SizedBox(width: 8),
              Text('No se puede eliminar'),
            ],
          ),
          content: Text(
            'El crédito tiene un saldo pendiente de ${CurrencyUtils.format(widget.credit.pendingBalance)}.\n\nPor seguridad contable, solo se pueden eliminar créditos que estén 100% pagados y finalizados.',
            style: FontTokens.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: ColorTokens.error),
            SizedBox(width: 8),
            Text('¿Eliminar crédito finalizado?'),
          ],
        ),
        content: Text(
          'Esta acción no se puede deshacer. Se eliminará el crédito de ${widget.credit.clientName} junto con todas sus cuotas y cargos históricos.',
          style: FontTokens.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorTokens.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(widget.credit.id);
            },
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final customersAsync = ref.watch(customersFutureProvider);
    final productsAsync = ref.watch(productsFutureProvider);

    final registeredCustomers = customersAsync.asData?.value ?? [];
    final productsList = productsAsync.asData?.value ?? [];

    final matchingCustomers = _customerQuery.trim().isEmpty
        ? <Customer>[]
        : registeredCustomers.where((c) =>
            c.name.toLowerCase().contains(_customerQuery.toLowerCase()) ||
            (c.documentId.isNotEmpty && c.documentId.contains(_customerQuery))).toList();

    final matchingProducts = _productQuery.trim().isEmpty
        ? <Product>[]
        : productsList.where((p) =>
            p.name.toLowerCase().contains(_productQuery.toLowerCase()) ||
            p.sku.toLowerCase().contains(_productQuery.toLowerCase())).toList();

    final bool isFullyPaid = widget.credit.status == 'finalizado' || widget.credit.pendingBalance <= 0 || widget.credit.totalPaid >= widget.credit.totalSale;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buscador de Clientes
            CustomTextField(
              label: 'Nombre del Cliente (Escribe para buscar)',
              hint: 'Escribe nombre o documento CC…',
              controller: _nameCtrl,
              onChanged: (val) {
                setState(() {
                  _customerQuery = val;
                  _showCustomerResults = true;
                });
              },
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),

            if (_showCustomerResults && matchingCustomers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceElevated,
                  border: Border.all(color: ColorTokens.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matchingCustomers.length,
                  separatorBuilder: (ctx, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final c = matchingCustomers[idx];
                    final docInfo = c.documentId.isNotEmpty ? '${c.documentType}: ${c.documentId}' : 'Sin doc';
                    final phoneInfo = c.phone.isNotEmpty ? 'Tel: ${c.phone}' : 'Sin tel';
                    return ListTile(
                      dense: true,
                      title: Text(c.name, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('$docInfo · $phoneInfo', style: FontTokens.bodySmall),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: ColorTokens.primary),
                      onTap: () {
                        setState(() {
                          _nameCtrl.text = c.name;
                          _phoneCtrl.text = c.phone;
                          _addressCtrl.text = c.address;
                          _docIdCtrl.text = c.documentId;
                          _docType = c.documentType.isNotEmpty ? c.documentType : 'CC';
                          _customerQuery = '';
                          _showCustomerResults = false;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Tipo y Número de Documento Identificación
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIPO (OPCIONAL)',
                        style: FontTokens.bodySmall.copyWith(
                          color: ColorTokens.lightTextSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _docType,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'CC', child: Text('CC')),
                          DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                          DropdownMenuItem(value: 'CE', child: Text('CE')),
                          DropdownMenuItem(value: 'Pasaporte', child: Text('PAS')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _docType = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: CustomTextField(
                    label: 'N° Documento (opcional)',
                    hint: '1098765432',
                    controller: _docIdCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: CustomPhoneInput(
                    label: 'Teléfono (opcional)',
                    hint: '300 123 4567',
                    controller: _phoneCtrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Dirección (opcional)',
                    hint: 'Cra 5 #12-34',
                    controller: _addressCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Buscador de Productos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Producto(s) (Escribe o Escanea)',
                    hint: 'Escribe nombre o SKU del producto…',
                    controller: _productsCtrl,
                    onChanged: (val) {
                      setState(() {
                        _productQuery = val;
                        _showProductResults = true;
                      });
                    },
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: ColorTokens.primary, size: 24),
                    tooltip: 'Escanear producto con cámara',
                    onPressed: () async {
                      final sku = await BarcodeScannerModal.scan(context);
                      if (sku != null && mounted) {
                        final found = productsList.where((p) => p.sku.toLowerCase() == sku.toLowerCase()).firstOrNull;
                        if (found != null) {
                          _productsCtrl.text = found.name;
                          _totalSaleCtrl.text = found.price.toStringAsFixed(0);
                        } else {
                          _productsCtrl.text = 'SKU: $sku';
                        }
                        setState(() {
                          _showProductResults = false;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            if (_showProductResults && matchingProducts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceElevated,
                  border: Border.all(color: ColorTokens.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matchingProducts.length,
                  separatorBuilder: (ctx, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final p = matchingProducts[idx];
                    return ListTile(
                      dense: true,
                      title: Text(p.name, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('SKU: ${p.sku} · Stock: ${p.stock} uds', style: FontTokens.bodySmall),
                      trailing: Text(currencyFmt.format(p.price), style: FontTokens.moneySmall.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold)),
                      onTap: () {
                        setState(() {
                          _productsCtrl.text = p.name;
                          _totalSaleCtrl.text = p.price.toStringAsFixed(0);
                          _productQuery = '';
                          _showProductResults = false;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: CustomMoneyInput(
                    label: 'Total Venta',
                    hint: '3200000',
                    controller: _totalSaleCtrl,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'N° Cuotas',
                    hint: '12',
                    controller: _totalQuotasCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FRECUENCIA DE PAGO',
                        style: FontTokens.bodySmall.copyWith(
                          color: ColorTokens.lightTextSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                          DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                          DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                          DropdownMenuItem(value: 'diario', child: Text('Diario')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _frequency = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Tasa Interés (%)',
                    hint: '5',
                    controller: _customInterestCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            CustomMoneyInput(
              label: 'Valor por Cuota (Personalizable)',
              hint: 'Ingresa o edita el valor de la cuota',
              controller: _customQuotaCtrl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            CustomTextField(
              label: 'Notas Adicionales (Opcional)',
              hint: 'Observaciones...',
              controller: _extraNotesCtrl,
            ),
            const SizedBox(height: 16),

            if (_quotaValue > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorTokens.primary.withAlpha(20),
                  border: Border.all(color: ColorTokens.primary.withAlpha(60)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('VALOR POR CUOTA:', style: FontTokens.label.copyWith(fontSize: 11)),
                    Text(
                      currencyFmt.format(_quotaValue),
                      style: FontTokens.h3.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            CustomButton(
              text: 'Guardar Cambios',
              icon: Icons.save_outlined,
              isLoading: _isSubmitting,
              onPressed: _handleSave,
            ),
            const SizedBox(height: 10),

            CustomButton(
              text: isFullyPaid ? 'Eliminar Crédito' : 'Eliminar Crédito (Solo al 100% pagado)',
              icon: isFullyPaid ? Icons.delete_outline : Icons.lock_outline,
              isSecondary: true,
              onPressed: _handleDelete,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

