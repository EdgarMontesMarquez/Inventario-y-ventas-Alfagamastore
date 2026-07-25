import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/base_repositories.dart';
import '../repositories/supabase_product_repository.dart';
import '../repositories/supabase_sale_repository.dart';
import '../repositories/supabase_credit_repository.dart';
import '../repositories/supabase_customer_repository.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/credit.dart';
import '../models/customer.dart';

import '../repositories/supabase_cash_shift_repository.dart';
import '../models/cash_shift.dart';

// Repositorios de datos en vivo conectados a Supabase PostgreSQL
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return SupabaseProductRepository(Supabase.instance.client);
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SupabaseSaleRepository(Supabase.instance.client);
});

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  return SupabaseCreditRepository(Supabase.instance.client);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return SupabaseCustomerRepository(Supabase.instance.client);
});

final cashShiftRepositoryProvider = Provider<SupabaseCashShiftRepository>((ref) {
  return SupabaseCashShiftRepository(Supabase.instance.client);
});

// Providers de consulta reactiva de datos optimizados con keepAlive para rendimiento instantáneo (0ms latency)
final productsFutureProvider = FutureProvider<List<Product>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts();
});

final salesFutureProvider = FutureProvider<List<Sale>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(saleRepositoryProvider);
  return repo.getSales();
});

final creditsFutureProvider = FutureProvider<List<Credit>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(creditRepositoryProvider);
  return repo.getCredits();
});

final customersFutureProvider = FutureProvider<List<Customer>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomers();
});

final activeCashShiftProvider = FutureProvider<CashShift?>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(cashShiftRepositoryProvider);
  return repo.getActiveShift();
});
