import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import 'app_logo.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/widgets/custom_buttons.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';


class ReceiptModal extends ConsumerWidget {
  final Sale sale;

  const ReceiptModal({super.key, required this.sale});

  static Future<void> show(BuildContext context, Sale sale) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ReceiptModal(sale: sale),
      ),
    );
  }

  Future<void> _printReceiptPdf(BuildContext context, WidgetRef ref) async {
    final storeSettings = ref.read(settingsProvider);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');

    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context pdfContext) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                storeSettings.storeName.toUpperCase(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'NIT: ${storeSettings.nit}\n${storeSettings.address} · Tel: ${storeSettings.phone}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TICKET #${(sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id).toUpperCase()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFmt.format(sale.createdAt.toLocal()), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),
              pw.Column(
                children: sale.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [                        pw.Expanded(
                          child: pw.Text('${item.qty}x ${item.productName}', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Text(CurrencyUtils.format(item.unitPrice * item.qty), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL PAGADO:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(CurrencyUtils.format(sale.total), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('MÉTODO:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(sale.paymentMethod.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                storeSettings.receiptFooter,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDoc.save(),
        name: 'Ticket_${sale.id}.pdf',
      );
    } catch (_) {
      final bytes = await pdfDoc.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Ticket_${sale.id}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Ticket de Venta POS PDF');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeSettings = ref.watch(settingsProvider);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');

    final receiptText = '''
${storeSettings.storeName.toUpperCase()}
NIT: ${storeSettings.nit}
${storeSettings.address} · Tel: ${storeSettings.phone}
----------------------------------------
TICKET #${(sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id).toUpperCase()}
Fecha: ${dateFmt.format(sale.createdAt.toLocal())}
----------------------------------------
${sale.items.map((i) => '${i.qty}x ${i.productName} - ${CurrencyUtils.format(i.unitPrice * i.qty)}').join('\n')}
----------------------------------------
TOTAL: ${CurrencyUtils.format(sale.total)}
Método: ${sale.paymentMethod.toUpperCase()}
${storeSettings.receiptFooter}
    ''';

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppLogo(size: 32),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            storeSettings.storeName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.8),
          ),
          Text(
            'NIT: ${storeSettings.nit} · ${storeSettings.address}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          Text(
            'Tel: ${storeSettings.phone}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 8),

          Text(
            'TICKET #${(sale.id.length >= 8 ? sale.id.substring(0, 8) : sale.id).toUpperCase()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'JetBrains Mono'),
          ),
          Text(
            'Fecha: ${dateFmt.format(sale.createdAt.toLocal())}',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const _DashedDivider(),
          const SizedBox(height: 8),

          // Items List
          Column(
            children: sale.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.qty}x ${item.productName}',
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyUtils.format(item.unitPrice * item.qty),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black, fontFamily: 'JetBrains Mono'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),
          const _DashedDivider(),
          const SizedBox(height: 8),

          // Payment Summary & Totals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL PAGADO:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(
                CurrencyUtils.format(sale.total),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'JetBrains Mono'),
              ),
            ],
          ),

          if (sale.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nota: ${sale.note}',
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54),
            ),
          ],

          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 12),

          Text(
            storeSettings.receiptFooter,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Imprimir PDF',
                  icon: Icons.print_outlined,
                  onPressed: () => _printReceiptPdf(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: ColorTokens.text),
                onPressed: () {
                  Share.share(receiptText, subject: 'Ticket de Venta - ${storeSettings.storeName}');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            );
          }),
        );
      },
    );
  }
}
