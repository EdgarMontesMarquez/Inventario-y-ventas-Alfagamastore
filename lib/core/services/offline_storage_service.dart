import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/product.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/credit.dart';
import '../../shared/models/customer.dart';
import '../../shared/models/cash_shift.dart';
import '../../shared/models/store_settings.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  Directory? _storageDir;

  Future<Directory> _getDir() async {
    if (_storageDir != null) return _storageDir!;
    try {
      _storageDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      _storageDir = Directory.current;
    }
    return _storageDir!;
  }

  Future<File> _getFile(String filename) async {
    final dir = await _getDir();
    final file = File('${dir.path}/alfagama_$filename');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<void> _writeJson(String filename, dynamic data) async {
    try {
      final file = await _getFile(filename);
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error escribiendo en $filename: $e');
    }
  }

  Future<dynamic> _readJson(String filename) async {
    try {
      final file = await _getFile(filename);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content);
    } catch (e) {
      debugPrint('Error leyendo de $filename: $e');
      return null;
    }
  }

  // ================= PRODUCTS =================
  Future<void> saveProducts(List<Product> products) async {
    final list = products.map((p) => {
      'id': p.id,
      'sku': p.sku,
      'name': p.name,
      'category': p.category,
      'price': p.price,
      'cost': p.cost,
      'stock': p.stock,
      'min_stock': p.minStock,
      'image_url': p.imageUrl,
    }).toList();
    await _writeJson('products.json', list);
  }

  Future<List<Product>> getProducts() async {
    final data = await _readJson('products.json');
    if (data == null || data is! List) return [];
    return data.map((m) => Product(
      id: m['id']?.toString() ?? '',
      sku: m['sku']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      category: m['category']?.toString() ?? 'Sin categoría',
      price: (m['price'] as num? ?? 0).toDouble(),
      cost: (m['cost'] as num? ?? 0).toDouble(),
      stock: (m['stock'] as num? ?? 0).toInt(),
      minStock: (m['min_stock'] as num? ?? 5).toInt(),
      imageUrl: m['image_url']?.toString(),
    )).toList();
  }

  Future<void> saveOrUpdateProduct(Product product) async {
    final list = await getProducts();
    final index = list.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      list[index] = product;
    } else {
      list.add(product);
    }
    await saveProducts(list);
  }

  Future<void> removeProduct(String id) async {
    final list = await getProducts();
    list.removeWhere((p) => p.id == id);
    await saveProducts(list);
  }

  // ================= SALES =================
  Future<void> saveSales(List<Sale> sales) async {
    final list = sales.map((s) => {
      'id': s.id,
      'total': s.total,
      'payment_method': s.paymentMethod,
      'note': s.note,
      'receipt_image_url': s.receiptImageUrl,
      'created_at': s.createdAt.toIso8601String(),
      'items': s.items.map((it) => {
        'product_id': it.productId,
        'product_name': it.productName,
        'unit_price': it.unitPrice,
        'qty': it.qty,
      }).toList(),
    }).toList();
    await _writeJson('sales.json', list);
  }

  Future<List<Sale>> getSales() async {
    final data = await _readJson('sales.json');
    if (data == null || data is! List) return [];
    return data.map((m) {
      final items = (m['items'] as List? ?? []).map((it) => SaleItem(
        productId: it['product_id']?.toString() ?? '',
        productName: it['product_name']?.toString() ?? '',
        qty: (it['qty'] as num? ?? 1).toInt(),
        unitPrice: (it['unit_price'] as num? ?? 0).toDouble(),
      )).toList();

      return Sale(
        id: m['id']?.toString() ?? '',
        total: (m['total'] as num? ?? 0).toDouble(),
        paymentMethod: m['payment_method']?.toString() ?? 'efectivo',
        note: m['note']?.toString() ?? '',
        receiptImageUrl: m['receipt_image_url']?.toString(),
        createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
        items: items,
      );
    }).toList();
  }

  Future<void> addSale(Sale sale) async {
    final list = await getSales();
    list.insert(0, sale);
    await saveSales(list);
  }

  // ================= CREDITS =================
  Future<void> saveCredits(List<Credit> credits) async {
    final list = credits.map((c) => {
      'id': c.id,
      'client_name': c.clientName,
      'client_phone': c.clientPhone,
      'client_address': c.clientAddress,
      'products': c.products,
      'total_sale': c.totalSale,
      'start_date': c.startDate.toIso8601String(),
      'payment_frequency': c.paymentFrequency,
      'total_quotas': c.totalQuotas,
      'quota_value': c.quotaValue,
      'general_notes': c.generalNotes,
      'installments': c.installments.map((inst) => {
        'quota_number': inst.quotaNumber,
        'due_date': inst.dueDate.toIso8601String(),
        'quota_value': inst.quotaValue,
        'paid_amount': inst.paidAmount,
        'paid_date': inst.paidDate?.toIso8601String(),
        'payment_method': inst.paymentMethod,
        'notes': inst.notes,
        'receipt_image_url': inst.receiptImageUrl,
      }).toList(),
      'charges': c.charges.map((ch) => {
        'id': ch.id,
        'credit_id': ch.creditId,
        'concept': ch.concept,
        'amount': ch.amount,
        'distribution_method': ch.distributionMethod,
        'created_at': ch.createdAt.toIso8601String(),
        'created_by': ch.createdBy,
        'notes': ch.notes,
      }).toList(),
    }).toList();
    await _writeJson('credits.json', list);
  }

  Future<List<Credit>> getCredits() async {
    final data = await _readJson('credits.json');
    if (data == null || data is! List) return [];
    return data.map((m) {
      final installments = (m['installments'] as List? ?? []).map((inst) => CreditInstallment(
        quotaNumber: (inst['quota_number'] as num? ?? 1).toInt(),
        dueDate: inst['due_date'] != null ? DateTime.tryParse(inst['due_date']) ?? DateTime.now() : DateTime.now(),
        quotaValue: (inst['quota_value'] as num? ?? 0).toDouble(),
        paidAmount: (inst['paid_amount'] as num? ?? 0).toDouble(),
        paidDate: inst['paid_date'] != null ? DateTime.tryParse(inst['paid_date']) : null,
        paymentMethod: inst['payment_method']?.toString() ?? '',
        notes: inst['notes']?.toString() ?? '',
        receiptImageUrl: inst['receipt_image_url']?.toString(),
      )).toList();

      final charges = (m['charges'] as List? ?? []).map((ch) => CreditCharge(
        id: ch['id']?.toString() ?? '',
        creditId: ch['credit_id']?.toString() ?? '',
        concept: ch['concept']?.toString() ?? '',
        amount: (ch['amount'] as num? ?? 0).toDouble(),
        distributionMethod: ch['distribution_method']?.toString() ?? 'distribute_remaining',
        createdAt: ch['created_at'] != null ? DateTime.tryParse(ch['created_at']) ?? DateTime.now() : DateTime.now(),
        createdBy: ch['created_by']?.toString() ?? 'Administrador',
        notes: ch['notes']?.toString() ?? '',
      )).toList();

      return Credit(
        id: m['id']?.toString() ?? '',
        clientName: m['client_name']?.toString() ?? '',
        clientPhone: m['client_phone']?.toString() ?? '',
        clientAddress: m['client_address']?.toString() ?? '',
        products: m['products']?.toString() ?? '',
        totalSale: (m['total_sale'] as num? ?? 0).toDouble(),
        startDate: m['start_date'] != null ? DateTime.tryParse(m['start_date']) ?? DateTime.now() : DateTime.now(),
        paymentFrequency: m['payment_frequency']?.toString() ?? 'semanal',
        totalQuotas: (m['total_quotas'] as num? ?? 1).toInt(),
        quotaValue: (m['quota_value'] as num? ?? 0).toDouble(),
        installments: installments,
        charges: charges,
        generalNotes: m['general_notes']?.toString() ?? '',
      );
    }).toList();
  }

  Future<void> saveOrUpdateCredit(Credit credit) async {
    final list = await getCredits();
    final index = list.indexWhere((c) => c.id == credit.id);
    if (index >= 0) {
      list[index] = credit;
    } else {
      list.insert(0, credit);
    }
    await saveCredits(list);
  }

  Future<void> removeCredit(String id) async {
    final list = await getCredits();
    list.removeWhere((c) => c.id == id);
    await saveCredits(list);
  }

  // ================= CUSTOMERS =================
  Future<void> saveCustomers(List<Customer> customers) async {
    final list = customers.map((c) => {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
      'address': c.address,
      'document_type': c.documentType,
      'document_id': c.documentId,
      'total_purchases': c.totalPurchases,
      'active_credit_balance': c.activeCreditBalance,
      'created_at': c.createdAt.toIso8601String(),
    }).toList();
    await _writeJson('customers.json', list);
  }

  Future<List<Customer>> getCustomers() async {
    final data = await _readJson('customers.json');
    if (data == null || data is! List) return [];
    return data.map((m) => Customer(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      phone: m['phone']?.toString() ?? '',
      address: m['address']?.toString() ?? '',
      documentType: m['document_type']?.toString() ?? 'CC',
      documentId: m['document_id']?.toString() ?? '',
      totalPurchases: (m['total_purchases'] as num? ?? 0).toDouble(),
      activeCreditBalance: (m['active_credit_balance'] as num? ?? 0).toDouble(),
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at']) ?? DateTime.now() : DateTime.now(),
    )).toList();
  }

  Future<void> saveOrUpdateCustomer(Customer customer) async {
    final list = await getCustomers();
    final index = list.indexWhere((c) => c.id == customer.id || (c.documentId.isNotEmpty && c.documentId == customer.documentId));
    if (index >= 0) {
      list[index] = customer;
    } else {
      list.insert(0, customer);
    }
    await saveCustomers(list);
  }

  // ================= CASH SHIFT & EXPENSES =================
  Future<void> saveActiveShift(CashShift? shift) async {
    if (shift == null) {
      await _writeJson('active_shift.json', null);
      return;
    }
    final map = {
      'id': shift.id,
      'user_id': shift.userId,
      'user_name': shift.userName,
      'initial_amount': shift.initialAmount,
      'cash_sales': shift.cashSales,
      'transfer_sales': shift.transferSales,
      'cash_credits': shift.cashCredits,
      'total_expenses': shift.totalExpenses,
      'expected_amount': shift.expectedAmount,
      'actual_amount': shift.actualAmount,
      'difference': shift.difference,
      'status': shift.status,
      'opened_at': shift.openedAt.toIso8601String(),
      'closed_at': shift.closedAt?.toIso8601String(),
      'notes': shift.notes,
      'expenses': shift.expenses.map((e) => {
        'id': e.id,
        'shift_id': e.shiftId,
        'description': e.description,
        'amount': e.amount,
        'created_at': e.createdAt.toIso8601String(),
      }).toList(),
    };
    await _writeJson('active_shift.json', map);
  }

  Future<CashShift?> getActiveShift() async {
    final m = await _readJson('active_shift.json');
    if (m == null || m is! Map<String, dynamic>) return null;

    final expenses = (m['expenses'] as List? ?? []).map((e) => CashExpense(
      id: e['id']?.toString() ?? '',
      shiftId: e['shift_id']?.toString() ?? '',
      description: e['description']?.toString() ?? '',
      amount: (e['amount'] as num? ?? 0).toDouble(),
      createdAt: e['created_at'] != null ? DateTime.tryParse(e['created_at']) ?? DateTime.now() : DateTime.now(),
    )).toList();

    return CashShift(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      userName: m['user_name']?.toString() ?? '',
      initialAmount: (m['initial_amount'] as num? ?? 0).toDouble(),
      cashSales: (m['cash_sales'] as num? ?? 0).toDouble(),
      transferSales: (m['transfer_sales'] as num? ?? 0).toDouble(),
      cashCredits: (m['cash_credits'] as num? ?? 0).toDouble(),
      totalExpenses: (m['total_expenses'] as num? ?? 0).toDouble(),
      expectedAmount: (m['expected_amount'] as num? ?? 0).toDouble(),
      actualAmount: (m['actual_amount'] as num?)?.toDouble(),
      difference: (m['difference'] as num?)?.toDouble(),
      status: m['status']?.toString() ?? 'open',
      openedAt: m['opened_at'] != null ? DateTime.tryParse(m['opened_at']) ?? DateTime.now() : DateTime.now(),
      closedAt: m['closed_at'] != null ? DateTime.tryParse(m['closed_at']) : null,
      notes: m['notes']?.toString() ?? '',
      expenses: expenses,
    );
  }

  // ================= CATEGORIES =================
  Future<void> saveCategories(List<String> categories) async {
    await _writeJson('categories.json', categories);
  }

  Future<List<String>> getCategories() async {
    final data = await _readJson('categories.json');
    if (data == null || data is! List) return ['Todos'];
    return data.map((e) => e.toString()).toList();
  }

  // ================= SETTINGS =================
  Future<void> saveSettings(StoreSettings settings) async {
    final map = {
      'storeName': settings.storeName,
      'nit': settings.nit,
      'phone': settings.phone,
      'address': settings.address,
      'receiptFooter': settings.receiptFooter,
      'currencySymbol': settings.currencySymbol,
      'soundOnScan': settings.soundOnScan,
      'autoPrintReceipt': settings.autoPrintReceipt,
    };
    await _writeJson('store_settings.json', map);
  }

  Future<StoreSettings?> getSettings() async {
    final map = await _readJson('store_settings.json');
    if (map == null || map is! Map<String, dynamic>) return null;
    return StoreSettings(
      storeName: map['storeName'] ?? 'Alfa Gama Store',
      nit: map['nit'] ?? '900.123.456-7',
      phone: map['phone'] ?? '300 123 4567',
      address: map['address'] ?? 'Cra 5 #12-34',
      receiptFooter: map['receiptFooter'] ?? '¡GRACIAS POR SU COMPRA!',
      currencySymbol: map['currencySymbol'] ?? 'COP (\$)',
      soundOnScan: (map['soundOnScan'] as bool?) ?? true,
      autoPrintReceipt: (map['autoPrintReceipt'] as bool?) ?? true,
    );
  }
}
