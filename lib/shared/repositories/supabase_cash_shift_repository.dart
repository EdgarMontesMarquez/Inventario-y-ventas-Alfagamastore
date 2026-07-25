import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cash_shift.dart';

class SupabaseCashShiftRepository {
  final SupabaseClient client;

  SupabaseCashShiftRepository(this.client);

  Future<CashShift?> getActiveShift() async {
    try {
      final response = await client
          .from('cash_shifts')
          .select('*')
          .eq('status', 'open')
          .order('opened_at', ascending: false)
          .maybeSingle();

      if (response == null) return null;

      final String shiftId = response['id'].toString();
      final DateTime openedAt = DateTime.parse(response['opened_at']);
      double computedCashSales = 0.0;
      double computedTransferSales = 0.0;
      double computedCashCredits = 0.0;

      // 1. Sumar ventas en efectivo y transferencias desde la apertura del turno
      try {
        final salesRes = await client
            .from('sales')
            .select('total, payment_method, created_at');

        for (var s in salesRes as List) {
          final DateTime saleDate = DateTime.parse(s['created_at']);
          final String pm = (s['payment_method'] ?? '').toString().toLowerCase();

          if (saleDate.isAfter(openedAt) || saleDate.isAtSameMomentAs(openedAt)) {
            if (pm.contains('efectivo')) {
              computedCashSales += (s['total'] as num).toDouble();
            } else if (pm.contains('transferencia') || pm.contains('nequi') || pm.contains('daviplata')) {
              computedTransferSales += (s['total'] as num).toDouble();
            }
          }
        }
      } catch (_) {}

      // 2. Sumar abonos a créditos en efectivo desde la apertura del turno
      try {
        final creditsRes = await client
            .from('credit_installments')
            .select('paid_amount, amount, is_paid, paid_at, payment_method, notes');

        for (var c in creditsRes as List) {
          if (c['paid_at'] != null) {
            final DateTime paidDate = DateTime.parse(c['paid_at']);
            final String pm = (c['payment_method'] ?? '').toString().toLowerCase();

            if (paidDate.isAfter(openedAt) || paidDate.isAtSameMomentAs(openedAt)) {
              if (pm.contains('efectivo')) {
                final double quotaVal = (c['amount'] as num).toDouble();
                final bool isPaid = c['is_paid'] == true;
                double pAmt = (c['paid_amount'] as num? ?? 0).toDouble();
                if (pAmt == 0) {
                  pAmt = isPaid ? quotaVal : 0.0;
                  final String notesStr = c['notes'] ?? '';
                  if (notesStr.contains('Abono: \$')) {
                    try {
                      final part = notesStr.split('Abono: \$')[1].split(' ')[0];
                      pAmt = double.tryParse(part) ?? pAmt;
                    } catch (_) {}
                  }
                }
                computedCashCredits += pAmt;
              }
            }
          }
        }
      } catch (_) {}

      // 3. Cargar egresos del turno
      List<CashExpense> expensesList = [];
      try {
        final expensesRes = await client
            .from('cash_expenses')
            .select('*')
            .eq('shift_id', shiftId)
            .order('created_at', ascending: false);

        expensesList = (expensesRes as List).map((e) {
          return CashExpense(
            id: e['id'].toString(),
            shiftId: e['shift_id'].toString(),
            description: e['description'] ?? '',
            amount: (e['amount'] as num).toDouble(),
            createdAt: DateTime.parse(e['created_at']),
          );
        }).toList();
      } catch (_) {}

      final double initial = (response['initial_amount'] as num).toDouble();
      final double totalExp = expensesList.fold(0.0, (sum, ex) => sum + ex.amount);
      final double expected = initial + computedCashSales + computedCashCredits - totalExp;

      return CashShift(
        id: shiftId,
        userId: response['user_id']?.toString() ?? '',
        userName: response['user_name'] ?? 'Empleado',
        initialAmount: initial,
        cashSales: computedCashSales,
        transferSales: computedTransferSales,
        cashCredits: computedCashCredits,
        totalExpenses: totalExp,
        expectedAmount: expected,
        actualAmount: response['actual_amount'] != null ? (response['actual_amount'] as num).toDouble() : null,
        difference: response['difference'] != null ? (response['difference'] as num).toDouble() : null,
        status: response['status'] ?? 'open',
        openedAt: openedAt,
        closedAt: response['closed_at'] != null ? DateTime.parse(response['closed_at']) : null,
        notes: response['notes'] ?? '',
        expenses: expensesList,
      );
    } catch (_) {
      return null;
    }
  }

  Future<double> getLastClosedShiftAmount() async {
    try {
      final res = await client
          .from('cash_shifts')
          .select('actual_amount, expected_amount')
          .eq('status', 'closed')
          .order('closed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        if (res['actual_amount'] != null && (res['actual_amount'] as num) > 0) {
          return (res['actual_amount'] as num).toDouble();
        }
        if (res['expected_amount'] != null && (res['expected_amount'] as num) > 0) {
          return (res['expected_amount'] as num).toDouble();
        }
      }
    } catch (_) {}
    return 100000.0;
  }

  Future<void> openShift(double initialAmount, String userName) async {
    final user = client.auth.currentUser;
    await client.from('cash_shifts').insert({
      'user_id': user?.id,
      'user_name': userName,
      'initial_amount': initialAmount,
      'expected_amount': initialAmount,
      'status': 'open',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> addExpense(String shiftId, String description, double amount) async {
    await client.from('cash_expenses').insert({
      'shift_id': shiftId,
      'description': description,
      'amount': amount,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final shift = await client.from('cash_shifts').select('total_expenses, initial_amount, cash_sales, cash_credits').eq('id', shiftId).single();
    final newExpenses = (shift['total_expenses'] as num? ?? 0).toDouble() + amount;
    final initial = (shift['initial_amount'] as num? ?? 0).toDouble();
    final sales = (shift['cash_sales'] as num? ?? 0).toDouble();
    final credits = (shift['cash_credits'] as num? ?? 0).toDouble();
    final expected = initial + sales + credits - newExpenses;

    await client.from('cash_shifts').update({
      'total_expenses': newExpenses,
      'expected_amount': expected,
    }).eq('id', shiftId);
  }

  Future<void> closeShift(String shiftId, double actualAmount, String notes) async {
    final activeShift = await getActiveShift();
    final double expected = activeShift?.expectedAmount ?? actualAmount;
    final double diff = actualAmount - expected;

    await client.from('cash_shifts').update({
      'cash_sales': activeShift?.cashSales ?? 0.0,
      'cash_credits': activeShift?.cashCredits ?? 0.0,
      'total_expenses': activeShift?.totalExpenses ?? 0.0,
      'expected_amount': expected,
      'actual_amount': actualAmount,
      'difference': diff,
      'status': 'closed',
      'closed_at': DateTime.now().toUtc().toIso8601String(),
      'notes': notes,
    }).eq('id', shiftId);
  }

  Future<List<CashShift>> getShiftHistory() async {
    try {
      final response = await client
          .from('cash_shifts')
          .select('*')
          .order('opened_at', ascending: false)
          .limit(50);

      final List<CashShift> result = [];

      for (var map in (response as List)) {
        final shiftId = map['id'].toString();
        List<CashExpense> expensesList = [];

        try {
          final expRes = await client.from('cash_expenses').select('*').eq('shift_id', shiftId);
          expensesList = (expRes as List).map((e) {
            return CashExpense(
              id: e['id'].toString(),
              shiftId: e['shift_id'].toString(),
              description: e['description'] ?? '',
              amount: (e['amount'] as num).toDouble(),
              createdAt: DateTime.parse(e['created_at']),
            );
          }).toList();
        } catch (_) {}

        result.add(CashShift(
          id: shiftId,
          userId: map['user_id']?.toString() ?? '',
          userName: map['user_name'] ?? 'Empleado',
          initialAmount: (map['initial_amount'] as num).toDouble(),
          cashSales: (map['cash_sales'] as num? ?? 0).toDouble(),
          transferSales: 0.0,
          cashCredits: (map['cash_credits'] as num? ?? 0).toDouble(),
          totalExpenses: (map['total_expenses'] as num? ?? 0).toDouble(),
          expectedAmount: (map['expected_amount'] as num? ?? 0).toDouble(),
          actualAmount: map['actual_amount'] != null ? (map['actual_amount'] as num).toDouble() : null,
          difference: map['difference'] != null ? (map['difference'] as num).toDouble() : null,
          status: map['status'] ?? 'closed',
          openedAt: DateTime.parse(map['opened_at']),
          closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at']) : null,
          notes: map['notes'] ?? '',
          expenses: expensesList,
        ));
      }

      return result;
    } catch (_) {
      return [];
    }
  }
}
