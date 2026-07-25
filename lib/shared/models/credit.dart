class CreditInstallment {
  final int quotaNumber;
  final DateTime dueDate;
  final double quotaValue;
  final double paidAmount;
  final DateTime? paidDate;
  final String paymentMethod;
  final String notes;
  final String? receiptImageUrl;

  const CreditInstallment({
    required this.quotaNumber,
    required this.dueDate,
    required this.quotaValue,
    required this.paidAmount,
    this.paidDate,
    required this.paymentMethod,
    required this.notes,
    this.receiptImageUrl,
  });

  CreditInstallment copyWith({
    int? quotaNumber,
    DateTime? dueDate,
    double? quotaValue,
    double? paidAmount,
    DateTime? paidDate,
    String? paymentMethod,
    String? notes,
    String? receiptImageUrl,
  }) {
    return CreditInstallment(
      quotaNumber: quotaNumber ?? this.quotaNumber,
      dueDate: dueDate ?? this.dueDate,
      quotaValue: quotaValue ?? this.quotaValue,
      paidAmount: paidAmount ?? this.paidAmount,
      paidDate: paidDate ?? this.paidDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
    );
  }

  String get status {
    if (paidAmount >= quotaValue) return 'pagado';
    if (paidAmount > 0) return 'parcial';
    // Compara solo fecha sin hora para vencido
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (due.isBefore(today)) return 'vencido';
    return 'pendiente';
  }
}

class Credit {
  final String id;
  final String clientName;
  final String clientPhone;
  final String clientAddress;
  final String products;
  final double totalSale;
  final DateTime startDate;
  final String paymentFrequency; // 'semanal' | 'quincenal' | 'mensual'
  final int totalQuotas;
  final double quotaValue;
  final List<CreditInstallment> installments;
  final String generalNotes;

  const Credit({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.clientAddress,
    required this.products,
    required this.totalSale,
    required this.startDate,
    required this.paymentFrequency,
    required this.totalQuotas,
    required this.quotaValue,
    required this.installments,
    required this.generalNotes,
  });

  Credit copyWith({
    String? id,
    String? clientName,
    String? clientPhone,
    String? clientAddress,
    String? products,
    double? totalSale,
    DateTime? startDate,
    String? paymentFrequency,
    int? totalQuotas,
    double? quotaValue,
    List<CreditInstallment>? installments,
    String? generalNotes,
  }) {
    return Credit(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAddress: clientAddress ?? this.clientAddress,
      products: products ?? this.products,
      totalSale: totalSale ?? this.totalSale,
      startDate: startDate ?? this.startDate,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      totalQuotas: totalQuotas ?? this.totalQuotas,
      quotaValue: quotaValue ?? this.quotaValue,
      installments: installments ?? this.installments,
      generalNotes: generalNotes ?? this.generalNotes,
    );
  }

  double get totalPaid => installments.fold(0.0, (sum, item) => sum + item.paidAmount);

  double get pendingBalance => (totalSale - totalPaid).clamp(0.0, double.infinity);

  double get progressPercentage => totalSale > 0 ? ((totalPaid / totalSale) * 100).clamp(0.0, 100.0) : 0;

  String get status {
    if (totalPaid >= totalSale) return 'finalizado';
    if (installments.any((item) => item.status == 'vencido')) return 'mora';
    return 'al_dia';
  }

  int get overdueQuotasCount => installments.where((item) => item.status == 'vencido').length;

  CreditInstallment? get nextDueInstallment {
    final pending = installments.where((item) => item.status != 'pagado').toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return pending.first;
  }

  static List<CreditInstallment> generateInstallments(
    DateTime startDate,
    String frequency,
    int totalQuotas,
    double quotaValue,
  ) {
    final daysStep = frequency == 'diario'
        ? 1
        : frequency == 'quincenal'
            ? 15
            : frequency == 'mensual'
                ? 30
                : 7;

    return List.generate(totalQuotas, (i) {
      return CreditInstallment(
        quotaNumber: i + 1,
        dueDate: startDate.add(Duration(days: i * daysStep)),
        quotaValue: quotaValue,
        paidAmount: 0,
        paymentMethod: '',
        notes: '',
      );
    });
  }
}
