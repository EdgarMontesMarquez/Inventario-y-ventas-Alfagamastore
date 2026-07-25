class SaleItem {
  final String productId;
  final String productName;
  final int qty;
  final double unitPrice;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
  });

  double get subtotal => qty * unitPrice;
}

class Sale {
  final String id;
  final List<SaleItem> items;
  final double total;
  final String paymentMethod; // 'efectivo' | 'tarjeta' | 'transferencia'
  final DateTime createdAt;
  final String note;
  final String? receiptImageUrl;

  const Sale({
    required this.id,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    required this.note,
    this.receiptImageUrl,
  });
}
