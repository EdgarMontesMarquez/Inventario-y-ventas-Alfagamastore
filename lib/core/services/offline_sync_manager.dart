import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/product.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/credit.dart';
import '../../shared/models/customer.dart';
import 'connectivity_service.dart';
import 'offline_storage_service.dart';
import 'sync_queue_service.dart';

enum SyncStatus { idle, syncing, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastError,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    String? lastError,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  final StreamController<SyncState> _stateController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  // Callbacks para notificar a los providers de la app cuando se actualicen datos
  void Function()? onDataRefreshed;

  SyncState get state => _state;
  Stream<SyncState> get stateStream => _stateController.stream;

  void initialize({void Function()? onRefresh}) {
    onDataRefreshed = onRefresh;
    _connectivity.initialize();

    // Actualizar conteo de pendientes al inicio
    _updatePendingCount();

    // Reaccionar cuando regrese el internet
    _connectivity.onlineStream.listen((isOnline) {
      if (isOnline) {
        debugPrint('🌐 Conexión restablecida. Iniciando sincronización automática...');
        syncNow();
      }
    });

    // Sincronizador en segundo plano cada 20 segundos
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_connectivity.isOnline && !_isSyncing) {
        syncNow();
      }
    });

    // Sincronización inicial si hay internet
    if (_connectivity.isOnline) {
      syncNow();
    }
  }

  Future<void> _updatePendingCount() async {
    final count = await _queue.getPendingCount();
    _state = _state.copyWith(pendingCount: count);
    _stateController.add(_state);
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    if (!_connectivity.isOnline) {
      await _updatePendingCount();
      return;
    }

    _isSyncing = true;
    _state = _state.copyWith(status: SyncStatus.syncing);
    _stateController.add(_state);

    try {
      final client = Supabase.instance.client;

      // 1. Procesar cola de acciones pendientes (FIFO)
      final queue = await _queue.getQueue();
      debugPrint('🔄 Sincronizando ${queue.length} acciones pendientes con Supabase...');

      for (final action in queue) {
        try {
          await _processAction(client, action);
          await _queue.removeAction(action.id);
        } catch (e) {
          debugPrint('⚠️ Error procesando acción de sincronización ${action.type} (${action.id}): $e');
          // Si falló por red, detener el ciclo y reintentar en el próximo turno
          break;
        }
      }

      final remaining = await _queue.getPendingCount();

      // 2. Descargar datos frescos de Supabase a la caché local
      await refreshLocalCache(client);

      _state = _state.copyWith(
        status: SyncStatus.idle,
        pendingCount: remaining,
        lastSyncTime: DateTime.now(),
        lastError: null,
      );
      _stateController.add(_state);

      // Notificar a la UI
      onDataRefreshed?.call();
      debugPrint('✅ Sincronización completada con éxito. Pendientes: $remaining');
    } catch (e) {
      debugPrint('❌ Error general en sincronización: $e');
      _state = _state.copyWith(
        status: SyncStatus.error,
        lastError: e.toString(),
      );
      _stateController.add(_state);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processAction(SupabaseClient client, SyncAction action) async {
    final payload = action.payload;

    switch (action.type) {
      case 'INSERT_SALE':
        final saleData = Map<String, dynamic>.from(payload['sale'] ?? {});
        final items = (payload['items'] as List? ?? []);

        // Insertar cabecera de venta
        final res = await client.from('sales').insert({
          'total': saleData['total'],
          'payment_method': saleData['payment_method'],
          'note': saleData['note'],
          'receipt_image_url': saleData['receipt_image_url'],
          'created_at': saleData['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
        }).select().single();

        final saleId = res['id'].toString();

        // Insertar items de la venta
        if (items.isNotEmpty) {
          final itemsPayload = items.map((it) => {
            'sale_id': saleId,
            'product_id': it['product_id'] != null && it['product_id'].toString().isNotEmpty ? it['product_id'] : null,
            'product_name': it['product_name'] ?? '',
            'qty': it['qty'] ?? 1,
            'unit_price': it['unit_price'] ?? 0,
          }).toList();
          await client.from('sale_items').insert(itemsPayload);
        }
        break;

      case 'ADD_PRODUCT':
        await client.from('products').insert({
          'sku': payload['sku'],
          'name': payload['name'],
          'category': payload['category'],
          'price': payload['price'],
          'cost': payload['cost'],
          'stock': payload['stock'],
          'min_stock': payload['min_stock'],
          'image_url': payload['image_url'],
        });
        break;

      case 'UPDATE_PRODUCT':
        await client.from('products').update({
          'sku': payload['sku'],
          'name': payload['name'],
          'category': payload['category'],
          'price': payload['price'],
          'cost': payload['cost'],
          'stock': payload['stock'],
          'min_stock': payload['min_stock'],
          'image_url': payload['image_url'],
        }).eq('id', payload['id']);
        break;

      case 'DELETE_PRODUCT':
        await client.from('products').delete().eq('id', payload['id']);
        break;

      case 'SELL_PRODUCT':
        final productId = payload['product_id']?.toString() ?? '';
        final qty = (payload['qty'] as num? ?? 1).toInt();
        if (productId.isNotEmpty) {
          final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(productId);
          Map<String, dynamic>? current;
          if (isUuid) {
            current = await client.from('products').select('id, stock').eq('id', productId).maybeSingle();
          }
          current ??= await client.from('products').select('id, stock').or('sku.eq.${productId.trim()},name.ilike.${productId.trim()}').maybeSingle();
          if (current != null) {
            final targetId = current['id'].toString();
            final currentStock = (current['stock'] as num).toInt();
            final newStock = (currentStock - qty).clamp(0, 999999);
            await client.from('products').update({'stock': newStock}).eq('id', targetId);
          }
        }
        break;

      case 'ADD_CUSTOMER':
      case 'UPSERT_CUSTOMER':
        final docId = (payload['document_id'] ?? '').toString().trim();
        Map<String, dynamic>? existing;
        if (docId.isNotEmpty) {
          existing = await client.from('customers').select('id').or('document_id.eq.$docId,name.ilike.${payload['name']}').maybeSingle();
        } else {
          existing = await client.from('customers').select('id').ilike('name', payload['name'] ?? '').maybeSingle();
        }

        if (existing != null) {
          await client.from('customers').update({
            'name': payload['name'],
            'phone': payload['phone'],
            'address': payload['address'],
            'document_type': payload['document_type'] ?? 'CC',
            'document_id': docId,
          }).eq('id', existing['id']);
        } else {
          await client.from('customers').insert({
            'name': payload['name'],
            'phone': payload['phone'],
            'address': payload['address'],
            'document_type': payload['document_type'] ?? 'CC',
            'document_id': docId,
            'credit_limit': payload['credit_limit'] ?? 0,
            'current_balance': payload['current_balance'] ?? 0,
          });
        }
        break;

      case 'UPDATE_CUSTOMER':
        await client.from('customers').update({
          'name': payload['name'],
          'phone': payload['phone'],
          'address': payload['address'],
          'document_type': payload['document_type'],
          'document_id': payload['document_id'],
        }).eq('id', payload['id']);
        break;

      case 'ADD_CREDIT':
        final creditMap = Map<String, dynamic>.from(payload['credit'] ?? {});
        final installments = (payload['installments'] as List? ?? []);

        final inserted = await client.from('credits').insert({
          'customer_name': creditMap['customer_name'],
          'customer_phone': creditMap['customer_phone'],
          'customer_address': creditMap['customer_address'],
          'products': creditMap['products'],
          'total_amount': creditMap['total_amount'],
          'installments_count': creditMap['installments_count'],
          'payment_frequency': creditMap['payment_frequency'],
          'notes': creditMap['notes'],
          'created_at': creditMap['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
        }).select().single();

        final newCreditId = inserted['id'].toString();

        if (installments.isNotEmpty) {
          final instPayload = installments.map((i) => {
            'credit_id': newCreditId,
            'number': i['quota_number'] ?? i['number'],
            'due_date': i['due_date'],
            'amount': i['quota_value'] ?? i['amount'],
            'is_paid': i['paid_amount'] != null && (i['paid_amount'] as num) >= (i['quota_value'] ?? i['amount']),
            'paid_amount': i['paid_amount'] ?? 0,
            'paid_at': i['paid_date'] ?? i['paid_at'],
            'payment_method': i['payment_method'] ?? '',
            'notes': i['notes'] ?? '',
            'receipt_image_url': i['receipt_image_url'],
          }).toList();
          await client.from('credit_installments').insert(instPayload);
        }
        break;

      case 'UPDATE_CREDIT':
        final creditId = payload['credit_id']?.toString() ?? '';
        final creditMap = Map<String, dynamic>.from(payload['credit'] ?? {});
        final installments = (payload['installments'] as List? ?? []);

        if (creditId.isNotEmpty) {
          await client.from('credits').update({
            'customer_name': creditMap['customer_name'],
            'customer_phone': creditMap['customer_phone'],
            'customer_address': creditMap['customer_address'],
            'products': creditMap['products'],
            'total_amount': creditMap['total_amount'],
            'installments_count': creditMap['installments_count'],
            'payment_frequency': creditMap['payment_frequency'],
            'notes': creditMap['notes'],
          }).eq('id', creditId);

          if (installments.isNotEmpty) {
            for (final i in installments) {
              final quotaNum = i['quota_number'] ?? i['number'];
              final paidAmt = (i['paid_amount'] as num? ?? 0).toDouble();
              final quotaVal = (i['quota_value'] as num? ?? 0).toDouble();
              final isPaid = paidAmt >= quotaVal && quotaVal > 0;

              // Actualizar cuota correspondiente
              await client.from('credit_installments').update({
                'amount': quotaVal,
                'paid_amount': paidAmt,
                'is_paid': isPaid,
                'paid_at': i['paid_date'] ?? i['paid_at'],
                'payment_method': i['payment_method'] ?? '',
                'notes': i['notes'] ?? '',
                'receipt_image_url': i['receipt_image_url'],
              }).eq('credit_id', creditId).eq('number', quotaNum);
            }
          }
        }
        break;

      case 'DELETE_CREDIT':
        final creditId = payload['id']?.toString() ?? '';
        if (creditId.isNotEmpty) {
          try {
            await client.from('credit_charges').delete().eq('credit_id', creditId);
          } catch (_) {}
          try {
            await client.from('credit_installments').delete().eq('credit_id', creditId);
          } catch (_) {}
          await client.from('credits').delete().eq('id', creditId);
        }
        break;

      case 'ADD_CREDIT_CHARGE':
        final creditId = payload['credit_id']?.toString() ?? '';
        final chargeData = Map<String, dynamic>.from(payload['charge'] ?? {});
        if (creditId.isNotEmpty) {
          try {
            await client.from('credit_charges').insert({
              'credit_id': creditId,
              'concept': chargeData['concept'],
              'amount': chargeData['amount'],
              'distribution_method': chargeData['distribution_method'],
              'created_by': chargeData['created_by'] ?? 'Administrador',
              'notes': chargeData['notes'] ?? '',
              'created_at': chargeData['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {}
          // Actualizar valor total del crédito
          final double newTotal = (payload['new_total'] as num? ?? 0).toDouble();
          if (newTotal > 0) {
            await client.from('credits').update({'total_amount': newTotal}).eq('id', creditId);
          }
        }
        break;

      case 'OPEN_SHIFT':
        await client.from('cash_shifts').insert({
          'user_id': payload['user_id'],
          'user_name': payload['user_name'],
          'initial_amount': payload['initial_amount'],
          'status': 'open',
          'opened_at': payload['opened_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'notes': payload['notes'] ?? '',
        });
        break;

      case 'CLOSE_SHIFT':
        final shiftId = payload['id']?.toString() ?? '';
        if (shiftId.isNotEmpty) {
          await client.from('cash_shifts').update({
            'status': 'closed',
            'closed_at': payload['closed_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'actual_amount': payload['actual_amount'],
            'difference': payload['difference'],
            'notes': payload['notes'] ?? '',
          }).eq('id', shiftId);
        }
        break;

      case 'ADD_CASH_EXPENSE':
        await client.from('cash_expenses').insert({
          'shift_id': payload['shift_id'],
          'description': payload['description'],
          'amount': payload['amount'],
          'created_at': payload['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
        });
        break;

      case 'ADD_CATEGORY':
        final name = payload['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          await client.from('categories').insert({'name': name});
        }
        break;
    }
  }

  /// Descarga el estado fresco de Supabase y lo guarda en la caché local
  Future<void> refreshLocalCache(SupabaseClient client) async {
    try {
      // 1. Productos
      final productsRes = await client.from('products').select().order('name');
      final products = (productsRes as List).map((m) => Product(
        id: m['id'].toString(),
        sku: m['sku']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        category: m['category']?.toString() ?? 'Sin categoría',
        price: (m['price'] as num? ?? 0).toDouble(),
        cost: (m['cost'] as num? ?? 0).toDouble(),
        stock: (m['stock'] as num? ?? 0).toInt(),
        minStock: (m['min_stock'] as num? ?? 5).toInt(),
        imageUrl: m['image_url']?.toString(),
      )).toList();
      await _storage.saveProducts(products);

      // 2. Ventas
      final salesRes = await client.from('sales').select('*, sale_items(*)').order('created_at', ascending: false).limit(200);
      final sales = (salesRes as List).map((m) {
        final items = (m['sale_items'] as List? ?? []).map((it) => SaleItem(
          productId: it['product_id']?.toString() ?? '',
          productName: it['product_name']?.toString() ?? '',
          qty: (it['qty'] as num? ?? 1).toInt(),
          unitPrice: (it['unit_price'] as num? ?? 0).toDouble(),
        )).toList();
        return Sale(
          id: m['id'].toString(),
          total: (m['total'] as num? ?? 0).toDouble(),
          paymentMethod: m['payment_method']?.toString() ?? 'efectivo',
          note: m['note']?.toString() ?? '',
          receiptImageUrl: m['receipt_image_url']?.toString(),
          createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
          items: items,
        );
      }).toList();
      await _storage.saveSales(sales);

      // 3. Clientes
      final customersRes = await client.from('customers').select().order('created_at', ascending: false);
      final customers = (customersRes as List).map((m) => Customer(
        id: m['id'].toString(),
        name: m['name'] ?? 'Cliente sin nombre',
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        documentType: m['document_type'] ?? 'CC',
        documentId: m['document_id'] ?? '',
        totalPurchases: (m['credit_limit'] as num? ?? 0).toDouble(),
        activeCreditBalance: (m['current_balance'] as num? ?? 0).toDouble(),
        createdAt: m['created_at'] != null ? DateTime.parse(m['created_at']) : DateTime.now(),
      )).toList();
      await _storage.saveCustomers(customers);

      // 4. Créditos
      dynamic creditsRes;
      try {
        creditsRes = await client.from('credits').select('*, credit_installments(*), credit_charges(*)').order('created_at', ascending: false);
      } catch (_) {
        creditsRes = await client.from('credits').select('*, credit_installments(*)').order('created_at', ascending: false);
      }
      final credits = (creditsRes as List).map((map) {
        final insts = (map['credit_installments'] as List? ?? []).map((instMap) {
          final double quotaVal = (instMap['amount'] as num).toDouble();
          final bool isPaid = instMap['is_paid'] == true;
          double rawPaid = (instMap['paid_amount'] as num? ?? 0).toDouble();
          if (rawPaid == 0) {
            rawPaid = isPaid ? quotaVal : 0.0;
            final String notesStr = instMap['notes'] ?? '';
            if (notesStr.contains('Abono: \$')) {
              try {
                final part = notesStr.split('Abono: \$')[1].split(' ')[0];
                rawPaid = double.tryParse(part) ?? rawPaid;
              } catch (_) {}
            }
          }
          return CreditInstallment(
            quotaNumber: (instMap['number'] as num).toInt(),
            dueDate: DateTime.parse(instMap['due_date']),
            quotaValue: quotaVal,
            paidAmount: rawPaid,
            paidDate: instMap['paid_at'] != null ? DateTime.parse(instMap['paid_at']) : null,
            paymentMethod: instMap['payment_method'] ?? '',
            notes: instMap['notes'] ?? '',
            receiptImageUrl: instMap['receipt_image_url'],
          );
        }).toList();
        insts.sort((a, b) => a.quotaNumber.compareTo(b.quotaNumber));

        final charges = (map['credit_charges'] as List? ?? []).map((chMap) => CreditCharge(
          id: chMap['id']?.toString() ?? '',
          creditId: chMap['credit_id']?.toString() ?? map['id'].toString(),
          concept: chMap['concept'] ?? 'Cargo Extra',
          amount: (chMap['amount'] as num? ?? 0).toDouble(),
          distributionMethod: chMap['distribution_method'] ?? 'distribute_remaining',
          createdAt: chMap['created_at'] != null ? DateTime.parse(chMap['created_at']) : DateTime.now(),
          createdBy: chMap['created_by'] ?? 'Administrador',
          notes: chMap['notes'] ?? '',
        )).toList();
        charges.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return Credit(
          id: map['id'].toString(),
          clientName: map['customer_name'] ?? '',
          clientPhone: map['customer_phone'] ?? '',
          clientAddress: map['customer_address'] ?? '',
          products: map['products'] ?? 'Productos Varios',
          totalSale: (map['total_amount'] as num).toDouble(),
          startDate: DateTime.parse(map['created_at']),
          paymentFrequency: map['payment_frequency'] ?? 'semanal',
          totalQuotas: (map['installments_count'] as num).toInt(),
          quotaValue: insts.isNotEmpty ? insts.first.quotaValue : 0.0,
          installments: insts,
          charges: charges,
          generalNotes: map['notes'] ?? '',
        );
      }).toList();
      await _storage.saveCredits(credits);

      // 5. Categorías
      try {
        final catRes = await client.from('categories').select('name').order('name');
        final catList = (catRes as List).map((e) => e['name'].toString()).toList();
        if (catList.isNotEmpty) {
          await _storage.saveCategories(['Todos', ...catList]);
        }
      } catch (_) {}

    } catch (e) {
      debugPrint('Error refrescando caché local desde Supabase: $e');
    }
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
    _stateController.close();
  }
}

// Riverpod Provider para el estado del sincronizador
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final manager = OfflineSyncManager();
  return manager.stateStream;
});
