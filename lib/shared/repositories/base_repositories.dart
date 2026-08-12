import '../models/product.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/credit.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts();
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> sellProduct(String productId, int qty);
}

abstract class SaleRepository {
  Future<List<Sale>> getSales();
  Future<void> addSale(Sale sale);
}

abstract class CustomerRepository {
  Future<List<Customer>> getCustomers();
  Future<void> addCustomer(Customer customer);
  Future<void> updateCustomer(Customer customer);
}

abstract class CreditRepository {
  Future<List<Credit>> getCredits();
  Future<Credit?> getCreditById(String id);
  Future<void> addCredit(Credit credit);
  Future<void> updateCredit(Credit credit);
  Future<void> addExtraCharge(String creditId, CreditCharge charge, Credit updatedCredit);
}
