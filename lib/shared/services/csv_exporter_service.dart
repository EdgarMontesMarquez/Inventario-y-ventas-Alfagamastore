import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/credit.dart';

class CsvExporterService {
  static Future<void> exportProductsCsv(List<Product> products) async {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0);

    final StringBuffer sb = StringBuffer();
    sb.writeln('SKU,Nombre,Categoria,Precio_Venta,Costo,Stock_Actual,Stock_Minimo');

    for (var p in products) {
      final sku = _cleanCsv(p.sku);
      final name = _cleanCsv(p.name);
      final cat = _cleanCsv(p.category);
      final price = currencyFmt.format(p.price).replaceAll('.', '');
      final cost = currencyFmt.format(p.cost).replaceAll('.', '');
      sb.writeln('"$sku","$name","$cat",$price,$cost,${p.stock},${p.minStock}');
    }

    await _shareCsvFile(sb.toString(), 'Inventario_AlfaGama_${_dateSuffix()}.csv');
  }

  static Future<void> exportSalesCsv(List<Sale> sales) async {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0);

    final StringBuffer sb = StringBuffer();
    sb.writeln('ID_Venta,Fecha_Hora,Total,Metodo_Pago,Items_Vendidos,Notas');

    for (var s in sales) {
      final itemsSummary = s.items.map((i) => '${i.qty}x ${i.productName}').join(' | ');
      final total = currencyFmt.format(s.total).replaceAll('.', '');
      final notes = _cleanCsv(s.note);

      sb.writeln('"${s.id}","${dateFmt.format(s.createdAt.toLocal())}",$total,"${s.paymentMethod}","${_cleanCsv(itemsSummary)}","$notes"');
    }

    await _shareCsvFile(sb.toString(), 'Ventas_AlfaGama_${_dateSuffix()}.csv');
  }

  static Future<void> exportCreditsCsv(List<Credit> credits) async {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0);

    final StringBuffer sb = StringBuffer();
    sb.writeln('Cliente,Telefono,Direccion,Productos,Total_Venta,Total_Abonado,Saldo_Pendiente,Estado,Frecuencia,Cuotas');

    for (var c in credits) {
      final name = _cleanCsv(c.clientName);
      final phone = _cleanCsv(c.clientPhone);
      final addr = _cleanCsv(c.clientAddress);
      final prods = _cleanCsv(c.products);
      final total = currencyFmt.format(c.totalSale).replaceAll('.', '');
      final paid = currencyFmt.format(c.totalPaid).replaceAll('.', '');
      final pending = currencyFmt.format(c.pendingBalance).replaceAll('.', '');

      sb.writeln('"$name","$phone","$addr","$prods",$total,$paid,$pending,"${c.status}","${c.paymentFrequency}",${c.totalQuotas}');
    }

    await _shareCsvFile(sb.toString(), 'Creditos_AlfaGama_${_dateSuffix()}.csv');
  }

  static String _cleanCsv(String text) {
    return text.replaceAll('"', '""').replaceAll('\n', ' ').trim();
  }

  static String _dateSuffix() {
    return DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  }

  static Future<void> _shareCsvFile(String csvContent, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvContent);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exportación de datos Alfa Gama Store: $filename',
    );
  }
}
