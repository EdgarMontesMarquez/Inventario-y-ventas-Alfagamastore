import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/credit.dart';
import 'base_repositories.dart';

class SupabaseCreditRepository implements CreditRepository {
  final SupabaseClient client;

  SupabaseCreditRepository(this.client);

  @override
  Future<List<Credit>> getCredits() async {
    dynamic response;
    try {
      response = await client.from('credits').select('*, credit_installments(*), credit_charges(*)').order('created_at', ascending: false);
    } catch (_) {
      // Fallback si la tabla credit_charges aún no ha sido migrada
      response = await client.from('credits').select('*, credit_installments(*)').order('created_at', ascending: false);
    }

    return (response as List).map((map) {
      final installmentsList = (map['credit_installments'] as List? ?? []).map((instMap) {
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

      installmentsList.sort((a, b) => a.quotaNumber.compareTo(b.quotaNumber));

      final chargesList = (map['credit_charges'] as List? ?? []).map((chMap) {
        return CreditCharge(
          id: chMap['id']?.toString() ?? '',
          creditId: chMap['credit_id']?.toString() ?? map['id'].toString(),
          concept: chMap['concept'] ?? 'Cargo Extra',
          amount: (chMap['amount'] as num? ?? 0).toDouble(),
          distributionMethod: chMap['distribution_method'] ?? 'distribute_remaining',
          createdAt: chMap['created_at'] != null ? DateTime.parse(chMap['created_at']) : DateTime.now(),
          createdBy: chMap['created_by'] ?? 'Administrador',
          notes: chMap['notes'] ?? '',
        );
      }).toList();

      chargesList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
        quotaValue: installmentsList.isNotEmpty ? installmentsList.first.quotaValue : 0.0,
        installments: installmentsList,
        charges: chargesList,
        generalNotes: map['notes'] ?? '',
      );
    }).toList();
  }

  @override
  Future<Credit?> getCreditById(String id) async {
    dynamic response;
    try {
      response = await client.from('credits').select('*, credit_installments(*), credit_charges(*)').eq('id', id).maybeSingle();
    } catch (_) {
      response = await client.from('credits').select('*, credit_installments(*)').eq('id', id).maybeSingle();
    }
    if (response == null) return null;

    final installmentsList = (response['credit_installments'] as List? ?? []).map((instMap) {
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

    installmentsList.sort((a, b) => a.quotaNumber.compareTo(b.quotaNumber));

    final chargesList = (response['credit_charges'] as List? ?? []).map((chMap) {
      return CreditCharge(
        id: chMap['id']?.toString() ?? '',
        creditId: chMap['credit_id']?.toString() ?? response['id'].toString(),
        concept: chMap['concept'] ?? 'Cargo Extra',
        amount: (chMap['amount'] as num? ?? 0).toDouble(),
        distributionMethod: chMap['distribution_method'] ?? 'distribute_remaining',
        createdAt: chMap['created_at'] != null ? DateTime.parse(chMap['created_at']) : DateTime.now(),
        createdBy: chMap['created_by'] ?? 'Administrador',
        notes: chMap['notes'] ?? '',
      );
    }).toList();

    chargesList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Credit(
      id: response['id'].toString(),
      clientName: response['customer_name'] ?? '',
      clientPhone: response['customer_phone'] ?? '',
      clientAddress: response['customer_address'] ?? '',
      products: response['products'] ?? 'Productos Varios',
      totalSale: (response['total_amount'] as num).toDouble(),
      startDate: DateTime.parse(response['created_at']),
      paymentFrequency: response['payment_frequency'] ?? 'semanal',
      totalQuotas: (response['installments_count'] as num).toInt(),
      quotaValue: installmentsList.isNotEmpty ? installmentsList.first.quotaValue : 0.0,
      installments: installmentsList,
      charges: chargesList,
      generalNotes: response['notes'] ?? '',
    );
  }

  @override
  Future<void> addCredit(Credit credit) async {
    // Extraer tipo y número de documento del campo de notas si existen
    String docType = 'CC';
    String docId = '';
    if (credit.generalNotes.contains('Documento:')) {
      try {
        final docText = credit.generalNotes.split('Documento:')[1].split('|')[0].trim();
        final docParts = docText.split(' ');
        if (docParts.length >= 2) {
          docType = docParts[0].trim();
          docId = docParts[1].trim();
        } else if (docParts.length == 1 && docParts[0].trim().isNotEmpty) {
          docType = docParts[0].trim();
        }
      } catch (_) {}
    }

    // Extraer tasa de interés de la nota
    double interestRate = 0.0;
    if (credit.generalNotes.contains('Interés:')) {
      try {
        final interestStr = credit.generalNotes.split('Interés:')[1].replaceAll('%', '').trim();
        interestRate = double.tryParse(interestStr) ?? 0.0;
      } catch (_) {}
    }

    final double baseAmount = credit.totalSale / (1 + (interestRate / 100));
    final double interestAmount = credit.totalSale - baseAmount;

    // 1. Auto-registrar o vincular cliente en la tabla public.customers sin duplicar
    String? customerId;
    try {
      final List existingCusts;
      if (docId.isNotEmpty) {
        existingCusts = await client
            .from('customers')
            .select('id')
            .or('document_id.eq.$docId,name.ilike.${credit.clientName}');
      } else {
        existingCusts = await client
            .from('customers')
            .select('id')
            .ilike('name', credit.clientName);
      }

      if (existingCusts.isNotEmpty) {
        customerId = existingCusts.first['id'].toString();
        // Actualizar datos del cliente existente sin crear un duplicado
        await client.from('customers').update({
          'phone': credit.clientPhone,
          'address': credit.clientAddress,
          'document_type': docType,
          'document_id': docId,
        }).eq('id', customerId);
      } else {
        final newCustRes = await client.from('customers').insert({
          'name': credit.clientName,
          'phone': credit.clientPhone,
          'address': credit.clientAddress,
          'document_type': docType,
          'document_id': docId,
          'credit_limit': credit.totalSale,
          'current_balance': credit.pendingBalance,
        }).select('id').single();
        customerId = newCustRes['id'].toString();
      }
    } catch (_) {}

    // Limpiar notas generales para evitar duplicar Documento/Interés si viene en el texto
    String cleanNotes = credit.generalNotes;
    if (cleanNotes.contains('Documento:')) {
      final parts = cleanNotes.split('|');
      if (parts.length > 2) {
        cleanNotes = parts.sublist(2).join('|').trim();
      } else {
        cleanNotes = '';
      }
    }

    // 2. Registrar el crédito relacional en public.credits
    final response = await client.from('credits').insert({
      'customer_id': customerId,
      'customer_name': credit.clientName,
      'customer_phone': credit.clientPhone,
      'customer_address': credit.clientAddress,
      'products': credit.products,
      'total_amount': credit.totalSale,
      'paid_amount': credit.totalPaid,
      'interest_rate': interestRate,
      'interest_amount': interestAmount,
      'installments_count': credit.totalQuotas,
      'payment_frequency': credit.paymentFrequency,
      'status': credit.status,
      'due_date': credit.startDate.add(Duration(days: credit.totalQuotas * 30)).toIso8601String(),
      'notes': cleanNotes.isNotEmpty ? cleanNotes : credit.generalNotes,
    }).select().single();

    final creditId = response['id'].toString();

    for (var inst in credit.installments) {
      await client.from('credit_installments').insert({
        'credit_id': creditId,
        'number': inst.quotaNumber,
        'amount': inst.quotaValue,
        'paid_amount': inst.paidAmount,
        'due_date': inst.dueDate.toIso8601String(),
        'is_paid': inst.paidAmount >= inst.quotaValue,
        'paid_at': inst.paidDate?.toIso8601String(),
        'payment_method': inst.paymentMethod,
        'notes': inst.notes,
        'receipt_image_url': inst.receiptImageUrl,
      });
    }
  }

  @override
  Future<void> updateCredit(Credit credit) async {
    await client.from('credits').update({
      'customer_name': credit.clientName,
      'customer_phone': credit.clientPhone,
      'customer_address': credit.clientAddress,
      'products': credit.products,
      'total_amount': credit.totalSale,
      'paid_amount': credit.totalPaid,
      'status': credit.status,
      'notes': credit.generalNotes,
    }).eq('id', credit.id);

    for (var inst in credit.installments) {
      final String formattedNotes = inst.paidAmount > 0
          ? 'Abono: \$${inst.paidAmount.toInt()} ${inst.notes}'.trim()
          : inst.notes;

      await client.from('credit_installments').update({
        'amount': inst.quotaValue,
        'paid_amount': inst.paidAmount,
        'due_date': inst.dueDate.toIso8601String(),
        'is_paid': inst.paidAmount >= inst.quotaValue,
        'paid_at': inst.paidDate?.toIso8601String(),
        'payment_method': inst.paymentMethod,
        'notes': formattedNotes,
        'receipt_image_url': inst.receiptImageUrl,
      }).eq('credit_id', credit.id).eq('number', inst.quotaNumber);
    }
  }

  @override
  Future<void> addExtraCharge(String creditId, CreditCharge charge, Credit updatedCredit) async {
    // 1. Guardar registro en la tabla credit_charges (si la tabla existe)
    try {
      await client.from('credit_charges').insert({
        'credit_id': creditId,
        'concept': charge.concept,
        'amount': charge.amount,
        'distribution_method': charge.distributionMethod,
        'created_by': charge.createdBy,
        'notes': charge.notes,
      });
    } catch (e) {
      // Ignorar si aún no se ha ejecutado la migración de la tabla en Supabase
    }

    // 2. Actualizar el monto total del crédito y la cantidad de cuotas en public.credits
    await client.from('credits').update({
      'total_amount': updatedCredit.totalSale,
      'installments_count': updatedCredit.totalQuotas,
      'status': updatedCredit.status,
    }).eq('id', creditId);

    // 3. Actualizar o insertar cuotas modificadas en public.credit_installments
    try {
      final existingInsts = await client.from('credit_installments').select('number').eq('credit_id', creditId);
      final existingNumbers = (existingInsts as List).map((i) => (i['number'] as num).toInt()).toSet();

      for (var inst in updatedCredit.installments) {
        final String formattedNotes = inst.paidAmount > 0
            ? 'Abono: \$${inst.paidAmount.toInt()} ${inst.notes}'.trim()
            : inst.notes;

        if (existingNumbers.contains(inst.quotaNumber)) {
          await client.from('credit_installments').update({
            'amount': inst.quotaValue,
            'paid_amount': inst.paidAmount,
            'due_date': inst.dueDate.toIso8601String(),
            'is_paid': inst.paidAmount >= inst.quotaValue,
            'paid_at': inst.paidDate?.toIso8601String(),
            'payment_method': inst.paymentMethod,
            'notes': formattedNotes,
            'receipt_image_url': inst.receiptImageUrl,
          }).eq('credit_id', creditId).eq('number', inst.quotaNumber);
        } else {
          await client.from('credit_installments').insert({
            'credit_id': creditId,
            'number': inst.quotaNumber,
            'amount': inst.quotaValue,
            'paid_amount': inst.paidAmount,
            'due_date': inst.dueDate.toIso8601String(),
            'is_paid': inst.paidAmount >= inst.quotaValue,
            'paid_at': inst.paidDate?.toIso8601String(),
            'payment_method': inst.paymentMethod,
            'notes': formattedNotes,
            'receipt_image_url': inst.receiptImageUrl,
          });
        }
      }
    } catch (_) {}

    // 4. Actualizar el saldo actual del cliente en public.customers
    try {
      final creditData = await client.from('credits').select('customer_id').eq('id', creditId).maybeSingle();
      if (creditData != null && creditData['customer_id'] != null) {
        final custId = creditData['customer_id'].toString();
        final cust = await client.from('customers').select('current_balance').eq('id', custId).maybeSingle();
        if (cust != null) {
          final double curBal = (cust['current_balance'] as num? ?? 0).toDouble();
          await client.from('customers').update({
            'current_balance': curBal + charge.amount,
          }).eq('id', custId);
        }
      }
    } catch (_) {}
  }
}

