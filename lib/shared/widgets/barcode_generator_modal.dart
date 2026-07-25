import 'dart:io';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/widgets/custom_buttons.dart';
import '../../core/utils/currency_formatter.dart';


class BarcodeGeneratorModal extends StatefulWidget {
  final String productName;
  final String sku;
  final double price;

  const BarcodeGeneratorModal({
    super.key,
    required this.productName,
    required this.sku,
    required this.price,
  });

  static Future<String?> show(
    BuildContext context, {
    required String productName,
    required String sku,
    required double price,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BarcodeGeneratorModal(
        productName: productName,
        sku: sku,
        price: price,
      ),
    );
  }

  @override
  State<BarcodeGeneratorModal> createState() => _BarcodeGeneratorModalState();
}

class _BarcodeGeneratorModalState extends State<BarcodeGeneratorModal> {
  late String _currentSku;
  bool _isChecking = false;
  String? _statusMessage;
  bool _isUnique = true;

  @override
  void initState() {
    super.initState();
    _currentSku = widget.sku.trim().isNotEmpty
        ? widget.sku.trim()
        : '770${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    _checkSkuUniqueness();
  }

  Future<void> _checkSkuUniqueness() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('id, name')
          .eq('sku', _currentSku)
          .maybeSingle();

      if (res != null) {
        _isUnique = false;
        _statusMessage = 'SKU ya registrado en Supabase para: ${res['name']}';
      } else {
        _isUnique = true;
        _statusMessage = 'Código único disponible en la base de datos';
      }
    } catch (_) {
      _isUnique = true;
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _generateNewSku() {
    setState(() {
      _currentSku = '770${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    });
    _checkSkuUniqueness();
  }

  Future<void> _saveAndSharePdf(pw.Document pdfDoc, String filename) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDoc.save(),
        name: filename,
      );
    } catch (_) {
      // Fallback nativo utilizando almacenamiento local y ShareXFiles
      final bytes = await pdfDoc.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Etiqueta Código de Barras PDF');
    }
  }

  Future<void> _printIndividualPdf() async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('ALFA GAMA STORE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    widget.productName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: _currentSku,
                    width: 180,
                    height: 50,
                    drawText: true,
                    textStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: PdfColors.black,
                    child: pw.Text(
                      'PRECIO: ${CurrencyUtils.format(widget.price)}',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await _saveAndSharePdf(pdfDoc, 'Etiqueta_${widget.productName}.pdf');
  }

  Future<void> _exportMassivePdf() async {
    final pdfDoc = pw.Document();

    List<Map<String, dynamic>> productsList = [];
    try {
      final res = await Supabase.instance.client.from('products').select('name, sku, price');
      productsList = List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    if (productsList.isEmpty) return;

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 0.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: productsList.map((p) {
                final pName = p['name'] ?? '';
                final pSku = p['sku'] ?? '';
                final pPrice = (p['price'] as num?)?.toDouble() ?? 0.0;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('ALFA GAMA STORE', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        pName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 3),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: pSku.isNotEmpty ? pSku : '000000',
                        width: 110,
                        height: 30,
                        drawText: true,
                        textStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: PdfColors.black,
                        child: pw.Text(
                          'PRECIO: ${CurrencyUtils.format(pPrice)}',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await _saveAndSharePdf(pdfDoc, 'Etiqueta_Masivas.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Etiqueta de Código de Barras',
                    style: FontTokens.h3.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: ColorTokens.lightTextSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sticker Preview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorTokens.lightBorderSubtle),
              ),
              child: Column(
                children: [
                  const Text(
                    'ALFA GAMA STORE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.productName.toUpperCase(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: _currentSku,
                    width: 200,
                    height: 54,
                    color: Colors.black,
                    drawText: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PRECIO: ${CurrencyUtils.format(widget.price)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_isChecking) ...[
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ColorTokens.lightBrandPrimary),
                ),
              ),
            ] else if (_statusMessage != null) ...[
              Text(
                _statusMessage!,
                style: FontTokens.bodySmall.copyWith(
                  color: _isUnique ? ColorTokens.lightBrandPrimary : ColorTokens.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),

            // Actions Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'PDF Etiqueta',
                    icon: Icons.picture_as_pdf_outlined,
                    isSecondary: true,
                    onPressed: _printIndividualPdf,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: 'PDF Masivo',
                    icon: Icons.grid_view_outlined,
                    isSecondary: true,
                    onPressed: _exportMassivePdf,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Nuevo SKU',
                    icon: Icons.refresh,
                    isSecondary: true,
                    onPressed: _generateNewSku,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: 'Usar Código',
                    icon: Icons.check,
                    onPressed: () {
                      Navigator.pop(context, _currentSku);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
