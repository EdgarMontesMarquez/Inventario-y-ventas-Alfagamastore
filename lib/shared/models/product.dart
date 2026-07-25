class Product {
  final String id;
  final String sku;
  final String name;
  final double price;
  final double cost;
  final int stock;
  final int minStock;
  final String category;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    required this.cost,
    required this.stock,
    required this.minStock,
    required this.category,
    this.imageUrl,
  });

  Product copyWith({
    String? id,
    String? sku,
    String? name,
    double? price,
    double? cost,
    int? stock,
    int? minStock,
    String? category,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  double get margin => price > 0 ? (price - cost) / price : 0;
}
