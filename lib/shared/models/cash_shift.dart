class CashExpense {
  final String id;
  final String shiftId;
  final String description;
  final double amount;
  final DateTime createdAt;

  const CashExpense({
    required this.id,
    required this.shiftId,
    required this.description,
    required this.amount,
    required this.createdAt,
  });
}

class CashShift {
  final String id;
  final String userId;
  final String userName;
  final double initialAmount;
  final double cashSales;
  final double transferSales;
  final double cashCredits;
  final double totalExpenses;
  final double expectedAmount;
  final double? actualAmount;
  final double? difference;
  final String status; // 'open' | 'closed'
  final DateTime openedAt;
  final DateTime? closedAt;
  final String notes;
  final List<CashExpense> expenses;

  const CashShift({
    required this.id,
    required this.userId,
    required this.userName,
    required this.initialAmount,
    required this.cashSales,
    this.transferSales = 0.0,
    required this.cashCredits,
    required this.totalExpenses,
    required this.expectedAmount,
    this.actualAmount,
    this.difference,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.notes,
    this.expenses = const [],
  });

  bool get isOpen => status == 'open';

  double get totalShiftSales => cashSales + transferSales;
  double get computedExpected => initialAmount + cashSales + cashCredits - totalExpenses;
}
