import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'base_repositories.dart';

class SupabaseProductRepository implements ProductRepository {
  final SupabaseClient client;

  SupabaseProductRepository(this.client);

  @override
  Future<List<Product>> getProducts() async {
    final response = await client.from('products').select().order('name');
    return (response as List).map((map) {
      return Product(
        id: map['id'].toString(),
        sku: map['sku']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        category: map['category']?.toString() ?? 'Sin categoría',
        price: (map['price'] as num? ?? 0).toDouble(),
        cost: (map['cost'] as num? ?? 0).toDouble(),
        stock: (map['stock'] as num? ?? 0).toInt(),
        minStock: (map['min_stock'] as num? ?? 5).toInt(),
        imageUrl: map['image_url']?.toString(),
      );
    }).toList();
  }

  @override
  Future<void> addProduct(Product product) async {
    await client.from('products').insert({
      'sku': product.sku,
      'name': product.name,
      'category': product.category,
      'price': product.price,
      'cost': product.cost,
      'stock': product.stock,
      'min_stock': product.minStock,
      'image_url': product.imageUrl,
    });
  }

  @override
  Future<void> updateProduct(Product product) async {
    await client.from('products').update({
      'sku': product.sku,
      'name': product.name,
      'category': product.category,
      'price': product.price,
      'cost': product.cost,
      'stock': product.stock,
      'min_stock': product.minStock,
      'image_url': product.imageUrl,
    }).eq('id', product.id);
  }

  @override
  Future<void> deleteProduct(String id) async {
    await client.from('products').delete().eq('id', id);
  }

  @override
  Future<void> sellProduct(String productId, int qty) async {
    if (productId.trim().isEmpty) return;

    try {
      // Validar si productId es un UUID válido (36 caracteres con guiones)
      final bool isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(productId);

      Map<String, dynamic>? current;
      if (isUuid) {
        current = await client
            .from('products')
            .select('id, stock')
            .eq('id', productId)
            .maybeSingle();
      }

      current ??= await client
          .from('products')
          .select('id, stock')
          .or('sku.eq.${productId.trim()},name.ilike.${productId.trim()}')
          .maybeSingle();

      if (current != null) {
        final targetId = current['id'].toString();
        final currentStock = (current['stock'] as num).toInt();
        final newStock = (currentStock - qty).clamp(0, 999999);
        await client.from('products').update({'stock': newStock}).eq('id', targetId);
      }
    } catch (_) {}
  }
}
