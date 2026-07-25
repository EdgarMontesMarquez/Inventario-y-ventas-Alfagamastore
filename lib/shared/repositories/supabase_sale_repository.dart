import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sale.dart';
import 'base_repositories.dart';

class SupabaseSaleRepository implements SaleRepository {
  final SupabaseClient client;

  SupabaseSaleRepository(this.client);

  @override
  Future<List<Sale>> getSales() async {
    final response = await client.from('sales').select('*, sale_items(*)').order('created_at', ascending: false);
    return (response as List).map((map) {
      final itemsList = (map['sale_items'] as List? ?? []).map((itemMap) {
        return SaleItem(
          productId: itemMap['product_id']?.toString() ?? '',
          productName: itemMap['product_name']?.toString() ?? '',
          unitPrice: (itemMap['unit_price'] as num? ?? 0).toDouble(),
          qty: (itemMap['qty'] as num? ?? 1).toInt(),
        );
      }).toList();

      return Sale(
        id: map['id'].toString(),
        createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
        total: (map['total'] as num? ?? 0).toDouble(),
        paymentMethod: map['payment_method']?.toString() ?? 'efectivo',
        items: itemsList,
        note: map['note']?.toString() ?? '',
        receiptImageUrl: map['receipt_image_url']?.toString(),
      );
    }).toList();
  }

  @override
  Future<void> addSale(Sale sale) async {
    final saleResponse = await client.from('sales').insert({
      'total': sale.total,
      'payment_method': sale.paymentMethod,
      'note': sale.note,
      'receipt_image_url': sale.receiptImageUrl,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    final saleId = saleResponse['id'].toString();

    final itemsPayload = sale.items.map((item) {
      return {
        'sale_id': saleId,
        'product_id': item.productId.isNotEmpty ? item.productId : null,
        'product_name': item.productName,
        'qty': item.qty,
        'unit_price': item.unitPrice,
      };
    }).toList();

    await client.from('sale_items').insert(itemsPayload);
  }
}
