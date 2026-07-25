import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/credit.dart';
import 'base_repositories.dart';

class SupabaseCreditRepository implements CreditRepository {
  final SupabaseClient client;

  SupabaseCreditRepository(this.client);

  @override
  Future<List<Credit>> getCredits() async {
    final response = await client.from('credits').select('*, credit_installments(*)').order('created_at', ascending: false);
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
        generalNotes: map['notes'] ?? '',
      );
    }).toList();
  }

  @override
  Future<Credit?> getCreditById(String id) async {
    final response = await client.from('credits').select('*, credit_installments(*)').eq('id', id).maybeSingle();
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
      generalNotes: response['notes'] ?? '',
    );
  }

  @override
  Future<void> addCredit(Credit credit) async {
    // Extraer tipo y número de documento del campo de notas si existen
    String docType = 'CC';
    String docId = DateTime.now().millisecondsSinceEpoch.toString();
    if (credit.generalNotes.contains('Documento:')) {
      try {
        final docParts = credit.generalNotes.split('Documento:')[1].split('|')[0].trim().split(' ');
        if (docParts.length >= 2) {
          docType = docParts[0].trim();
          docId = docParts[1].trim();
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
      final existingCusts = await client
          .from('customers')
          .select('id')
          .or('document_id.eq.$docId,name.ilike.${credit.clientName}');

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
      'notes': credit.generalNotes,
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
}
