import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/cash_shift.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../core/services/sync_queue_service.dart';
import 'supabase_cash_shift_repository.dart';

class OfflineFirstCashShiftRepository {
  final SupabaseCashShiftRepository _remoteRepo;
  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SupabaseClient _client;

  OfflineFirstCashShiftRepository(this._client)
      : _remoteRepo = SupabaseCashShiftRepository(_client);

  Future<CashShift?> getActiveShift() async {
    if (_connectivity.isOnline) {
      try {
        final shift = await _remoteRepo.getActiveShift();
        await _storage.saveActiveShift(shift);
        return shift;
      } catch (e) {
        debugPrint('⚠️ Error al obtener turno activo en línea: $e');
      }
    }

    // Calcular turno activo con los datos locales
    final localShift = await _storage.getActiveShift();
    if (localShift == null || localShift.status != 'open') return null;

    // Recalcular ventas y abonos locales desde la fecha de apertura
    final sales = await _storage.getSales();
    final credits = await _storage.getCredits();

    double computedCashSales = 0.0;
    double computedTransferSales = 0.0;
    double computedCashCredits = 0.0;

    for (final s in sales) {
      if (s.createdAt.isAfter(localShift.openedAt) || s.createdAt.isAtSameMomentAs(localShift.openedAt)) {
        final pm = s.paymentMethod.toLowerCase();
        if (pm.contains('efectivo')) {
          computedCashSales += s.total;
        } else if (pm.contains('transferencia') || pm.contains('nequi') || pm.contains('daviplata')) {
          computedTransferSales += s.total;
        }
      }
    }

    for (final c in credits) {
      for (final inst in c.installments) {
        if (inst.paidDate != null && (inst.paidDate!.isAfter(localShift.openedAt) || inst.paidDate!.isAtSameMomentAs(localShift.openedAt))) {
          final pm = inst.paymentMethod.toLowerCase();
          if (pm.contains('efectivo')) {
            computedCashCredits += inst.paidAmount;
          }
        }
      }
    }

    final double totalExp = localShift.expenses.fold(0.0, (sum, ex) => sum + ex.amount);
    final double expected = localShift.initialAmount + computedCashSales + computedCashCredits - totalExp;

    final updatedShift = CashShift(
      id: localShift.id,
      userId: localShift.userId,
      userName: localShift.userName,
      initialAmount: localShift.initialAmount,
      cashSales: computedCashSales,
      transferSales: computedTransferSales,
      cashCredits: computedCashCredits,
      totalExpenses: totalExp,
      expectedAmount: expected,
      actualAmount: localShift.actualAmount,
      difference: localShift.difference,
      status: localShift.status,
      openedAt: localShift.openedAt,
      closedAt: localShift.closedAt,
      notes: localShift.notes,
      expenses: localShift.expenses,
    );

    await _storage.saveActiveShift(updatedShift);
    return updatedShift;
  }

  Future<double> getLastClosedShiftAmount() async {
    if (_connectivity.isOnline) {
      try {
        return await _remoteRepo.getLastClosedShiftAmount();
      } catch (_) {}
    }
    return 100000.0;
  }

  Future<void> openShift(double initialAmount, String userName) async {
    final shiftId = const Uuid().v4();
    final now = DateTime.now();
    final user = _client.auth.currentUser;

    final newShift = CashShift(
      id: shiftId,
      userId: user?.id ?? '',
      userName: userName,
      initialAmount: initialAmount,
      cashSales: 0.0,
      transferSales: 0.0,
      cashCredits: 0.0,
      totalExpenses: 0.0,
      expectedAmount: initialAmount,
      status: 'open',
      openedAt: now,
      notes: '',
      expenses: [],
    );

    // 1. Guardar turno activo en local
    await _storage.saveActiveShift(newShift);

    // 2. Subir o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.openShift(initialAmount, userName);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error abriendo turno en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'OPEN_SHIFT',
        payload: {
          'id': shiftId,
          'user_id': user?.id,
          'user_name': userName,
          'initial_amount': initialAmount,
          'opened_at': now.toUtc().toIso8601String(),
          'notes': '',
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> addExpense(String shiftId, String description, double amount) async {
    final expense = CashExpense(
      id: const Uuid().v4(),
      shiftId: shiftId,
      description: description,
      amount: amount,
      createdAt: DateTime.now(),
    );

    // 1. Actualizar turno local
    final activeShift = await _storage.getActiveShift();
    if (activeShift != null) {
      final updatedExpenses = List<CashExpense>.from(activeShift.expenses)..insert(0, expense);
      final newTotalExpenses = activeShift.totalExpenses + amount;
      final newExpected = activeShift.expectedAmount - amount;

      final updated = CashShift(
        id: activeShift.id,
        userId: activeShift.userId,
        userName: activeShift.userName,
        initialAmount: activeShift.initialAmount,
        cashSales: activeShift.cashSales,
        transferSales: activeShift.transferSales,
        cashCredits: activeShift.cashCredits,
        totalExpenses: newTotalExpenses,
        expectedAmount: newExpected,
        status: activeShift.status,
        openedAt: activeShift.openedAt,
        notes: activeShift.notes,
        expenses: updatedExpenses,
      );
      await _storage.saveActiveShift(updated);
    }

    // 2. Subir o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.addExpense(shiftId, description, amount);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error agregando egreso en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'ADD_CASH_EXPENSE',
        payload: {
          'shift_id': shiftId,
          'description': description,
          'amount': amount,
          'created_at': expense.createdAt.toUtc().toIso8601String(),
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> closeShift(String shiftId, double actualAmount, String notes) async {
    final activeShift = await getActiveShift();
    final double expected = activeShift?.expectedAmount ?? actualAmount;
    final double diff = actualAmount - expected;
    final now = DateTime.now();

    // 1. Marcar turno local como cerrado
    if (activeShift != null) {
      final closed = CashShift(
        id: activeShift.id,
        userId: activeShift.userId,
        userName: activeShift.userName,
        initialAmount: activeShift.initialAmount,
        cashSales: activeShift.cashSales,
        transferSales: activeShift.transferSales,
        cashCredits: activeShift.cashCredits,
        totalExpenses: activeShift.totalExpenses,
        expectedAmount: expected,
        actualAmount: actualAmount,
        difference: diff,
        status: 'closed',
        openedAt: activeShift.openedAt,
        closedAt: now,
        notes: notes,
        expenses: activeShift.expenses,
      );
      await _storage.saveActiveShift(closed);
    }

    // 2. Subir o encolar
    bool synced = false;
    if (_connectivity.isOnline) {
      try {
        await _remoteRepo.closeShift(shiftId, actualAmount, notes);
        synced = true;
      } catch (e) {
        debugPrint('⚠️ Error cerrando turno en Supabase: $e');
      }
    }

    if (!synced) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'CLOSE_SHIFT',
        payload: {
          'id': shiftId,
          'actual_amount': actualAmount,
          'difference': diff,
          'notes': notes,
          'closed_at': now.toUtc().toIso8601String(),
        },
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<List<CashShift>> getShiftHistory() async {
    if (_connectivity.isOnline) {
      try {
        return await _remoteRepo.getShiftHistory();
      } catch (_) {}
    }
    final active = await _storage.getActiveShift();
    return active != null ? [active] : [];
  }
}
