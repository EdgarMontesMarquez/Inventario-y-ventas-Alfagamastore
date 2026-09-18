import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/credit.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/services/sync_queue_service.dart';
import 'base_repositories.dart';
import 'supabase_credit_repository.dart';

class OfflineFirstCreditRepository implements CreditRepository {
  final SupabaseCreditRepository _remoteRepo;
  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();
  final ConnectivityService _connectivity = ConnectivityService();

  OfflineFirstCreditRepository(SupabaseClient client)
      : _remoteRepo = SupabaseCreditRepository(client);

  @override
  Future<List<Credit>> getCredits() async {
    if (_connectivity.isOnline) {
      try {
        final credits = await _remoteRepo.getCredits();
        await _storage.saveCredits(credits);
        return credits;
      } catch (e) {
        debugPrint('⚠️ Error al consultar créditos en línea, cargando de almacenamiento local: $e');
      }
    }
    return await _storage.getCredits();
  }

  @override
  Future<Credit?> getCreditById(String id) async {
    if (_connectivity.isOnline) {
      try {
        final credit = await _remoteRepo.getCreditById(id);
        if (credit != null) {
          await _storage.saveOrUpdateCredit(credit);
          return credit;
        }
      } catch (e) {
        debugPrint('⚠️ Error buscando crédito por ID en línea: $e');
      }
    }
    final localCredits = await _storage.getCredits();
    try {
      return localCredits.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addCredit(Credit credit) async {
    final effectiveId = credit.id.trim().isEmpty ? const Uuid().v4() : credit.id;
    final effectiveCredit = credit.copyWith(id: effectiveId);

    // 1. Guardar de inmediato en almacenamiento local (Optimistic)
    await _storage.saveOrUpdateCredit(effectiveCredit);

    // 2. Subir a Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.addCredit(effectiveCredit);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error subiendo crédito a Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'ADD_CREDIT',
        payload: {
          'credit': {
            'id': effectiveCredit.id,
            'customer_name': effectiveCredit.clientName,
            'customer_phone': effectiveCredit.clientPhone,
            'customer_address': effectiveCredit.clientAddress,
            'products': effectiveCredit.products,
            'total_amount': effectiveCredit.totalSale,
            'installments_count': effectiveCredit.totalQuotas,
            'payment_frequency': effectiveCredit.paymentFrequency,
            'notes': effectiveCredit.generalNotes,
            'created_at': effectiveCredit.startDate.toUtc().toIso8601String(),
          },
          'installments': effectiveCredit.installments.map((i) => {
            'quota_number': i.quotaNumber,
            'due_date': i.dueDate.toIso8601String().split('T')[0],
            'quota_value': i.quotaValue,
            'paid_amount': i.paidAmount,
            'paid_date': i.paidDate?.toIso8601String(),
            'payment_method': i.paymentMethod,
            'notes': i.notes,
            'receipt_image_url': i.receiptImageUrl,
          }).toList(),
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> updateCredit(Credit credit) async {
    // 1. Actualizar de inmediato en local
    await _storage.saveOrUpdateCredit(credit);

    // 2. Subir a Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.updateCredit(credit);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error actualizando crédito en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'UPDATE_CREDIT',
        payload: {
          'credit_id': credit.id,
          'credit': {
            'customer_name': credit.clientName,
            'customer_phone': credit.clientPhone,
            'customer_address': credit.clientAddress,
            'products': credit.products,
            'total_amount': credit.totalSale,
            'installments_count': credit.totalQuotas,
            'payment_frequency': credit.paymentFrequency,
            'notes': credit.generalNotes,
          },
          'installments': credit.installments.map((i) => {
            'quota_number': i.quotaNumber,
            'due_date': i.dueDate.toIso8601String().split('T')[0],
            'quota_value': i.quotaValue,
            'paid_amount': i.paidAmount,
            'paid_date': i.paidDate?.toIso8601String(),
            'payment_method': i.paymentMethod,
            'notes': i.notes,
            'receipt_image_url': i.receiptImageUrl,
          }).toList(),
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> deleteCredit(String creditId) async {
    // 1. Eliminar localmente
    await _storage.removeCredit(creditId);

    // 2. Subir a Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.deleteCredit(creditId);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error eliminando crédito en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'DELETE_CREDIT',
        payload: {'id': creditId},
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> addExtraCharge(String creditId, CreditCharge charge, Credit updatedCredit) async {
    // 1. Actualizar el crédito completo con su nuevo cargo en almacenamiento local
    await _storage.saveOrUpdateCredit(updatedCredit);

    // 2. Subir a Supabase o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.addExtraCharge(creditId, charge, updatedCredit);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error registrando cargo extra en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'ADD_CREDIT_CHARGE',
        payload: {
          'credit_id': creditId,
          'charge': {
            'concept': charge.concept,
            'amount': charge.amount,
            'distribution_method': charge.distributionMethod,
            'created_by': charge.createdBy,
            'notes': charge.notes,
            'created_at': charge.createdAt.toUtc().toIso8601String(),
          },
          'new_total': updatedCredit.totalSale,
        },
        createdAt: DateTime.now(),
      ));
    }
  }
}
