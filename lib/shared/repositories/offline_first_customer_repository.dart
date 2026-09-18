import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/services/sync_queue_service.dart';
import 'base_repositories.dart';
import 'supabase_customer_repository.dart';

class OfflineFirstCustomerRepository implements CustomerRepository {
  final SupabaseCustomerRepository _remoteRepo;
  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  OfflineFirstCustomerRepository(SupabaseClient client)
      : _remoteRepo = SupabaseCustomerRepository(client);

  @override
  Future<List<Customer>> getCustomers() async {
    if (_connectivity.isOnline) {
      try {
        final customers = await _remoteRepo.getCustomers();
        await _storage.saveCustomers(customers);
        return customers;
      } catch (e) {
        debugPrint('⚠️ Error al consultar clientes en línea, cargando de almacenamiento local: $e');
      }
    }
    return await _storage.getCustomers();
  }

  @override
  Future<void> addCustomer(Customer customer) async {
    final effectiveId = customer.id.trim().isEmpty ? const Uuid().v4() : customer.id;
    final effectiveCustomer = Customer(
      id: effectiveId,
      name: customer.name,
      phone: customer.phone,
      address: customer.address,
      documentType: customer.documentType,
      documentId: customer.documentId,
      totalPurchases: customer.totalPurchases,
      activeCreditBalance: customer.activeCreditBalance,
      createdAt: customer.createdAt,
    );

    // 1. Guardar localmente
    await _storage.saveOrUpdateCustomer(effectiveCustomer);

    // 2. Subir a Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.addCustomer(effectiveCustomer);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error subiendo cliente a Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'ADD_CUSTOMER',
        payload: {
          'id': effectiveCustomer.id,
          'name': effectiveCustomer.name,
          'phone': effectiveCustomer.phone,
          'address': effectiveCustomer.address,
          'document_type': effectiveCustomer.documentType,
          'document_id': effectiveCustomer.documentId,
          'credit_limit': effectiveCustomer.totalPurchases,
          'current_balance': effectiveCustomer.activeCreditBalance,
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    // 1. Actualizar localmente
    await _storage.saveOrUpdateCustomer(customer);

    // 2. Subir a Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.updateCustomer(customer);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error actualizando cliente en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'UPDATE_CUSTOMER',
        payload: {
          'id': customer.id,
          'name': customer.name,
          'phone': customer.phone,
          'address': customer.address,
          'document_type': customer.documentType,
          'document_id': customer.documentId,
        },
        createdAt: DateTime.now(),
      ));
    }
  }
}
