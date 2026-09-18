import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/services/sync_queue_service.dart';
import 'base_repositories.dart';
import 'supabase_product_repository.dart';

class OfflineFirstProductRepository implements ProductRepository {
  final SupabaseProductRepository _remoteRepo;
  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  OfflineFirstProductRepository(SupabaseClient client)
      : _remoteRepo = SupabaseProductRepository(client);

  @override
  Future<List<Product>> getProducts() async {
    if (_connectivity.isOnline) {
      try {
        final products = await _remoteRepo.getProducts();
        await _storage.saveProducts(products);
        return products;
      } catch (e) {
        debugPrint('⚠️ Error al consultar productos en línea, cargando de almacenamiento local: $e');
      }
    }
    return await _storage.getProducts();
  }

  @override
  Future<void> addProduct(Product product) async {
    final effectiveId = product.id.trim().isEmpty ? const Uuid().v4() : product.id;
    final newProduct = product.copyWith(id: effectiveId);

    // 1. Guardar localmente de inmediato (Optimistic UI)
    await _storage.saveOrUpdateProduct(newProduct);

    // 2. Si hay conexión intentar subir a Supabase; si falla o no hay conexión, encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.addProduct(newProduct);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error subiendo producto nuevo a Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'ADD_PRODUCT',
        payload: {
          'id': newProduct.id,
          'sku': newProduct.sku,
          'name': newProduct.name,
          'category': newProduct.category,
          'price': newProduct.price,
          'cost': newProduct.cost,
          'stock': newProduct.stock,
          'min_stock': newProduct.minStock,
          'image_url': newProduct.imageUrl,
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    // 1. Actualizar localmente de inmediato
    await _storage.saveOrUpdateProduct(product);

    // 2. Intentar subir o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.updateProduct(product);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error actualizando producto en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'UPDATE_PRODUCT',
        payload: {
          'id': product.id,
          'sku': product.sku,
          'name': product.name,
          'category': product.category,
          'price': product.price,
          'cost': product.cost,
          'stock': product.stock,
          'min_stock': product.minStock,
          'image_url': product.imageUrl,
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    // 1. Eliminar localmente
    await _storage.removeProduct(id);

    // 2. Intentar eliminar en Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.deleteProduct(id);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error eliminando producto en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'DELETE_PRODUCT',
        payload: {'id': id},
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> sellProduct(String productId, int qty) async {
    if (productId.trim().isEmpty) return;

    // 1. Reducir stock local de inmediato
    final localProducts = await _storage.getProducts();
    final index = localProducts.indexWhere((p) =>
        p.id == productId ||
        p.sku.toLowerCase() == productId.trim().toLowerCase() ||
        p.name.toLowerCase() == productId.trim().toLowerCase());

    if (index >= 0) {
      final p = localProducts[index];
      final newStock = (p.stock - qty).clamp(0, 999999);
      localProducts[index] = p.copyWith(stock: newStock);
      await _storage.saveProducts(localProducts);
    }

    // 2. Sincronizar en la nube o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.sellProduct(productId, qty);
        synced = true;
      } catch (_) {}
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'SELL_PRODUCT',
        payload: {
          'product_id': productId,
          'qty': qty,
        },
        createdAt: DateTime.now(),
      ));
    }
  }
}
