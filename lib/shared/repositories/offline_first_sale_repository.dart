import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/services/sync_queue_service.dart';
import 'base_repositories.dart';
import 'supabase_sale_repository.dart';

class OfflineFirstSaleRepository implements SaleRepository {
  final SupabaseSaleRepository _remoteRepo;
  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  OfflineFirstSaleRepository(SupabaseClient client)
      : _remoteRepo = SupabaseSaleRepository(client);

  @override
  Future<List<Sale>> getSales() async {
    if (_connectivity.isOnline) {
      try {
        final sales = await _remoteRepo.getSales();
        await _storage.saveSales(sales);
        return sales;
      } catch (e) {
        debugPrint('⚠️ Error al consultar ventas en línea, cargando de almacenamiento local: $e');
      }
    }
    return await _storage.getSales();
  }

  @override
  Future<void> addSale(Sale sale) async {
    final effectiveId = sale.id.trim().isEmpty ? const Uuid().v4() : sale.id;
    final effectiveSale = Sale(
      id: effectiveId,
      items: sale.items,
      total: sale.total,
      paymentMethod: sale.paymentMethod,
      createdAt: sale.createdAt,
      note: sale.note,
      receiptImageUrl: sale.receiptImageUrl,
    );

    // 1. Guardar la venta en almacenamiento local inmediatamente
    await _storage.addSale(effectiveSale);

    // 2. Descontar el stock de cada producto vendido en la base de datos local
    final localProducts = await _storage.getProducts();
    for (final item in sale.items) {
      final index = localProducts.indexWhere((p) =>
          p.id == item.productId ||
          (item.productName.isNotEmpty && p.name.toLowerCase() == item.productName.toLowerCase()));

      if (index >= 0) {
        final p = localProducts[index];
        final newStock = (p.stock - item.qty).clamp(0, 999999);
        localProducts[index] = p.copyWith(stock: newStock);
      }
    }
    await _storage.saveProducts(localProducts);

    // 3. Si hay internet, intentar subir de inmediato
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.addSale(effectiveSale);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error subiendo venta a Supabase: $e');
      }
    }

    // 4. Si no se pudo subir o no hay internet, encolar para sincronización automática
    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'INSERT_SALE',
        payload: {
          'sale': {
            'id': effectiveSale.id,
            'total': effectiveSale.total,
            'payment_method': effectiveSale.paymentMethod,
            'note': effectiveSale.note,
            'receipt_image_url': effectiveSale.receiptImageUrl,
            'created_at': effectiveSale.createdAt.toUtc().toIso8601String(),
          },
          'items': effectiveSale.items.map((item) => {
            'product_id': item.productId,
            'product_name': item.productName,
            'qty': item.qty,
            'unit_price': item.unitPrice,
          }).toList(),
        },
        createdAt: DateTime.now(),
      ));
    }
  }
}
