import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/base_repositories.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/credit.dart';
import '../models/customer.dart';
import '../models/cash_shift.dart';
import '../repositories/offline_first_product_repository.dart';
import '../repositories/offline_first_sale_repository.dart';
import '../repositories/offline_first_credit_repository.dart';
import '../repositories/offline_first_customer_repository.dart';
import '../repositories/offline_first_cash_shift_repository.dart';

// Repositorios con soporte Offline-First y sincronización automática en Supabase
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return OfflineFirstProductRepository(Supabase.instance.client);
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return OfflineFirstSaleRepository(Supabase.instance.client);
});

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  return OfflineFirstCreditRepository(Supabase.instance.client);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return OfflineFirstCustomerRepository(Supabase.instance.client);
});

final cashShiftRepositoryProvider = Provider<OfflineFirstCashShiftRepository>((ref) {
  return OfflineFirstCashShiftRepository(Supabase.instance.client);
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
