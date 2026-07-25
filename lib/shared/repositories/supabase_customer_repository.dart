import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';
import 'base_repositories.dart';

class SupabaseCustomerRepository implements CustomerRepository {
  final SupabaseClient client;

  SupabaseCustomerRepository(this.client);

  @override
  Future<List<Customer>> getCustomers() async {
    final response = await client.from('customers').select().order('created_at', ascending: false);
    return (response as List).map((map) {
      return Customer(
        id: map['id'].toString(),
        name: map['name'] ?? 'Cliente sin nombre',
        phone: map['phone'] ?? '',
        address: map['address'] ?? '',
        documentType: map['document_type'] ?? 'CC',
        documentId: map['document_id'] ?? '',
        totalPurchases: (map['credit_limit'] as num? ?? 0).toDouble(),
        activeCreditBalance: (map['current_balance'] as num? ?? 0).toDouble(),
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> addCustomer(Customer customer) async {
    final String docId = customer.documentId.trim().isNotEmpty
        ? customer.documentId.trim()
        : 'CLI-${DateTime.now().millisecondsSinceEpoch}';

    // Verificar si el cliente ya existe por Documento de Identificación o por Nombre
    final existing = await client
        .from('customers')
        .select('id')
        .or('document_id.eq.$docId,name.ilike.${customer.name}')
        .maybeSingle();

    if (existing != null) {
      await client.from('customers').update({
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'document_type': customer.documentType.isEmpty ? 'CC' : customer.documentType,
        'document_id': docId,
      }).eq('id', existing['id']);
    } else {
      await client.from('customers').insert({
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'document_type': customer.documentType.isEmpty ? 'CC' : customer.documentType,
        'document_id': docId,
        'credit_limit': customer.totalPurchases,
        'current_balance': customer.activeCreditBalance,
      });
    }
  }
}
