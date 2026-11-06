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
    bool clearPaidDate = false,
    String? paymentMethod,
    String? notes,
    String? receiptImageUrl,
  }) {
    return CreditInstallment(
      quotaNumber: quotaNumber ?? this.quotaNumber,
      dueDate: dueDate ?? this.dueDate,
      quotaValue: quotaValue ?? this.quotaValue,
      paidAmount: paidAmount ?? this.paidAmount,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
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

class CreditCharge {
  final String id;
  final String creditId;
  final String concept;
  final double amount;
  final String distributionMethod; // 'distribute_remaining' | 'add_installment' | 'next_installment'
  final DateTime createdAt;
  final String createdBy;
  final String notes;

  const CreditCharge({
    required this.id,
    required this.creditId,
    required this.concept,
    required this.amount,
    required this.distributionMethod,
    required this.createdAt,
    this.createdBy = 'Administrador',
    this.notes = '',
  });

  CreditCharge copyWith({
    String? id,
    String? creditId,
    String? concept,
    double? amount,
    String? distributionMethod,
    DateTime? createdAt,
    String? createdBy,
    String? notes,
  }) {
    return CreditCharge(
      id: id ?? this.id,
      creditId: creditId ?? this.creditId,
      concept: concept ?? this.concept,
      amount: amount ?? this.amount,
      distributionMethod: distributionMethod ?? this.distributionMethod,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
    );
  }
}

class CreditPayment {
  final String id;
  final String creditId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? receiptImageUrl;
  final String notes;
  final String? shiftId;

  const CreditPayment({
    required this.id,
    required this.creditId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'efectivo',
    this.receiptImageUrl,
    this.notes = '',
    this.shiftId,
  });

  CreditPayment copyWith({
    String? id,
    String? creditId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? receiptImageUrl,
    String? notes,
    String? shiftId,
  }) {
    return CreditPayment(
      id: id ?? this.id,
      creditId: creditId ?? this.creditId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      notes: notes ?? this.notes,
      shiftId: shiftId ?? this.shiftId,
    );
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
  final List<CreditCharge> charges;
  final List<CreditPayment> payments;
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
    this.charges = const [],
    this.payments = const [],
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
    List<CreditCharge>? charges,
    List<CreditPayment>? payments,
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
      charges: charges ?? this.charges,
      payments: payments ?? this.payments,
      generalNotes: generalNotes ?? this.generalNotes,
    );
  }

  /// Limpia prefijos repetidos como "Abono: $50000 Abono: $50000" dejando solo la observación real
  static String cleanAbonoNotes(String rawNotes) {
    if (rawNotes.trim().isEmpty) return '';
    return rawNotes
        .replaceAll(RegExp(r'Abono:\s*\$?\d+(\.\d+)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'Abono previo registrado', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double get totalPaid {
    final instTotal = installments.fold(0.0, (sum, item) => sum + item.paidAmount);
    final payTotal = payments.fold(0.0, (sum, p) => sum + p.amount);
    return instTotal >= payTotal ? instTotal : payTotal;
  }

  /// Reconcilia cuotas y abonos históricos, corrigiendo cuotas que hayan sido
  /// alteradas en cascada sin fecha de pago (paidDate == null con paidAmount > 0)
  /// y limpiando notas duplicadas.
  static ({
    List<CreditInstallment> installments,
    List<CreditPayment> payments,
    bool needsInstallmentsRepair,
    List<CreditPayment> missingPaymentsToInsert,
  }) reconcileInstallmentsAndPayments(
    String creditId,
    List<CreditInstallment> baseInstallments,
    List<CreditPayment> basePayments,
  ) {
    var installments = baseInstallments
        .map((i) => i.copyWith(notes: cleanAbonoNotes(i.notes)))
        .toList()
      ..sort((a, b) => a.quotaNumber.compareTo(b.quotaNumber));

    var payments = basePayments
        .map((p) => p.copyWith(notes: cleanAbonoNotes(p.notes)))
        .toList();

    bool needsInstallmentsRepair = false;
    final List<CreditPayment> missingPaymentsToInsert = [];

    // Detectar si las cuotas fueron alteradas por la antigua distribución en cascada
    // (cuotas con paidAmount > 0 pero sin paidDate cuando existen abonos en credit_payments)
    final bool wasCascaded = payments.isNotEmpty &&
        installments.any((i) => i.paidAmount > 0 && i.paidDate == null);

    if (wasCascaded) {
      needsInstallmentsRepair = true;
      final chronologicalPayments = List<CreditPayment>.from(payments)
        ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

      installments = List.generate(installments.length, (idx) {
        final inst = installments[idx];
        if (idx < chronologicalPayments.length) {
          final p = chronologicalPayments[idx];
          return inst.copyWith(
            paidAmount: p.amount,
            paidDate: p.paymentDate,
            paymentMethod: p.paymentMethod,
            notes: cleanAbonoNotes(p.notes),
            receiptImageUrl: p.receiptImageUrl ?? inst.receiptImageUrl,
          );
        } else {
          return inst.copyWith(
            paidAmount: 0.0,
            clearPaidDate: true,
            paymentMethod: '',
            notes: '',
          );
        }
      });
    } else {
      // Si hay cuotas pagadas con fecha que aún no están en credit_payments, agregarlas
      for (final inst in installments) {
        if (inst.paidAmount > 0 && inst.paidDate != null) {
          final alreadyExists = payments.any((p) =>
              (p.amount - inst.paidAmount).abs() < 1 &&
              p.paymentDate.difference(inst.paidDate!).inMinutes.abs() <= 5);
          if (!alreadyExists) {
            final synthesized = CreditPayment(
              id: 'sync_${creditId}_${inst.quotaNumber}',
              creditId: creditId,
              amount: inst.paidAmount,
              paymentDate: inst.paidDate!,
              paymentMethod: inst.paymentMethod.isNotEmpty ? inst.paymentMethod : 'efectivo',
              receiptImageUrl: inst.receiptImageUrl,
              notes: cleanAbonoNotes(inst.notes),
            );
            payments.add(synthesized);
            missingPaymentsToInsert.add(synthesized);
          }
        }
      }
    }

    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return (
      installments: installments,
      payments: payments,
      needsInstallmentsRepair: needsInstallmentsRepair,
      missingPaymentsToInsert: missingPaymentsToInsert,
    );
  }

  /// Agrega un nuevo abono a la cuota seleccionada sin alterar las demás cuotas futuras
  Credit addPayment(CreditPayment payment, {int? quotaIndex}) {
    final cleanedPayment = payment.copyWith(notes: cleanAbonoNotes(payment.notes));
    final newPayments = [cleanedPayment, ...payments];
    newPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    final updatedInstallments = List<CreditInstallment>.from(installments);
    if (updatedInstallments.isNotEmpty) {
      int targetIdx = quotaIndex ?? updatedInstallments.indexWhere((i) => i.status != 'pagado');
      if (targetIdx < 0 || targetIdx >= updatedInstallments.length) {
        targetIdx = updatedInstallments.length - 1;
      }
      final targetInst = updatedInstallments[targetIdx];
      final cleanOldNote = cleanAbonoNotes(targetInst.notes);
      final cleanNewNote = cleanedPayment.notes;
      final combinedNote = [cleanOldNote, cleanNewNote]
          .where((s) => s.isNotEmpty)
          .toSet()
          .join(' | ');

      updatedInstallments[targetIdx] = targetInst.copyWith(
        paidAmount: targetInst.paidAmount + cleanedPayment.amount,
        paidDate: cleanedPayment.paymentDate,
        paymentMethod: cleanedPayment.paymentMethod,
        notes: combinedNote,
        receiptImageUrl: cleanedPayment.receiptImageUrl ?? targetInst.receiptImageUrl,
      );
    }

    return copyWith(
      payments: newPayments,
      installments: updatedInstallments,
    );
  }

  double get totalExtraCharges => charges.fold(0.0, (sum, item) => sum + item.amount);

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

  /// Aplica un cargo extra al crédito y recalcula las cuotas según el método elegido
  Credit applyExtraCharge({
    required CreditCharge charge,
  }) {
    final newTotalSale = totalSale + charge.amount;
    final newCharges = List<CreditCharge>.from(charges)..add(charge);
    final updatedInsts = List<CreditInstallment>.from(installments);

    final daysStep = paymentFrequency == 'diario'
        ? 1
        : paymentFrequency == 'quincenal'
            ? 15
            : paymentFrequency == 'mensual'
                ? 30
                : 7;

    int newTotalQuotas = totalQuotas;

    if (charge.distributionMethod == 'add_installment') {
      // Opción: Crear una nueva cuota al final
      final lastDate = updatedInsts.isNotEmpty ? updatedInsts.last.dueDate : startDate;
      final newDueDate = lastDate.add(Duration(days: daysStep));
      final nextNumber = updatedInsts.isNotEmpty ? updatedInsts.last.quotaNumber + 1 : 1;

      updatedInsts.add(
        CreditInstallment(
          quotaNumber: nextNumber,
          dueDate: newDueDate,
          quotaValue: charge.amount,
          paidAmount: 0.0,
          paymentMethod: '',
          notes: 'Cargo extra: ${charge.concept}',
        ),
      );
      newTotalQuotas = updatedInsts.length;
    } else if (charge.distributionMethod == 'next_installment') {
      // Opción: Cargar todo a la siguiente cuota inmediata no pagada
      final pendingIdx = updatedInsts.indexWhere((i) => i.status != 'pagado');
      if (pendingIdx >= 0) {
        final target = updatedInsts[pendingIdx];
        final existingNote = target.notes.isNotEmpty ? '${target.notes} | ' : '';
        updatedInsts[pendingIdx] = target.copyWith(
          quotaValue: target.quotaValue + charge.amount,
          notes: '$existingNote+Recargo: ${charge.concept} (\$${charge.amount.toInt()})',
        );
      } else {
        // Si no hay pendientes, añadir al final
        final lastDate = updatedInsts.isNotEmpty ? updatedInsts.last.dueDate : startDate;
        updatedInsts.add(
          CreditInstallment(
            quotaNumber: updatedInsts.length + 1,
            dueDate: lastDate.add(Duration(days: daysStep)),
            quotaValue: charge.amount,
            paidAmount: 0.0,
            paymentMethod: '',
            notes: 'Cargo extra: ${charge.concept}',
          ),
        );
        newTotalQuotas = updatedInsts.length;
      }
    } else {
      // Opción por defecto: 'distribute_remaining' (Prorrateo entre cuotas pendientes)
      final pendingIndices = <int>[];
      for (int i = 0; i < updatedInsts.length; i++) {
        if (updatedInsts[i].status != 'pagado') {
          pendingIndices.add(i);
        }
      }

      if (pendingIndices.isNotEmpty) {
        final portion = charge.amount / pendingIndices.length;
        for (final idx in pendingIndices) {
          final target = updatedInsts[idx];
          updatedInsts[idx] = target.copyWith(
            quotaValue: target.quotaValue + portion,
          );
        }
      } else {
        // Si todas estaban pagadas, añadir una nueva cuota
        final lastDate = updatedInsts.isNotEmpty ? updatedInsts.last.dueDate : startDate;
        updatedInsts.add(
          CreditInstallment(
            quotaNumber: updatedInsts.length + 1,
            dueDate: lastDate.add(Duration(days: daysStep)),
            quotaValue: charge.amount,
            paidAmount: 0.0,
            paymentMethod: '',
            notes: 'Cargo extra: ${charge.concept}',
          ),
        );
        newTotalQuotas = updatedInsts.length;
      }
    }

    return copyWith(
      totalSale: newTotalSale,
      totalQuotas: newTotalQuotas,
      installments: updatedInsts,
      charges: newCharges,
    );
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
