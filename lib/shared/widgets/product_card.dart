import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../core/design_system/widgets/custom_badges.dart';
import '../../core/utils/currency_formatter.dart';
import 'image_viewer_modal.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isEmpleado;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isEmpleado = false,
  });

  Widget _buildProductThumbnail(BuildContext context) {
    if (product.imageUrl == null || product.imageUrl!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final clean = product.imageUrl!.trim();

    Widget imgWidget;
    if (clean.startsWith('data:image') || clean.length > 500) {
      try {
        final base64Str = clean.contains(',') ? clean.split(',').last : clean;
        final bytes = base64Decode(base64Str);
        imgWidget = Image.memory(bytes, fit: BoxFit.cover, width: 85, height: double.infinity);
      } catch (_) {
        imgWidget = Container(width: 85, color: ColorTokens.lightBgSecondary, child: const Icon(Icons.inventory_2_outlined, color: ColorTokens.lightTextSecondary));
      }
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      imgWidget = Image.network(clean, fit: BoxFit.cover, width: 85, height: double.infinity, errorBuilder: (c, e, s) => Container(width: 85, color: ColorTokens.lightBgSecondary, child: const Icon(Icons.broken_image_outlined, color: ColorTokens.lightTextSecondary)));
    } else {
      final f = File(clean);
      if (f.existsSync()) {
        imgWidget = Image.file(f, fit: BoxFit.cover, width: 85, height: double.infinity);
      } else {
        imgWidget = Container(width: 85, color: ColorTokens.lightBgSecondary, child: const Icon(Icons.inventory_2_outlined, color: ColorTokens.lightTextSecondary));
      }
    }

    return GestureDetector(
      onTap: () => ImageViewerModal.show(context, imageUrl: clean, title: product.name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 75,
          height: 75,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imgWidget,
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = ColorTokens.lightSurfacePrimary;
    const borderCol = ColorTokens.lightBorderSubtle;
    const titleCol = ColorTokens.lightTextPrimary;
    const subCol = ColorTokens.lightTextSecondary;
    const primaryCol = ColorTokens.lightBrandPrimary;

    final marginPct = (product.margin * 100).round();
    final hasImage = product.imageUrl != null && product.imageUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: BorderShadowTokens.shadowLevel1,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasImage) ...[
                _buildProductThumbnail(context),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: FontTokens.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: titleCol,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${product.sku} · ${product.category}',
                                style: FontTokens.monoCode.copyWith(
                                  color: subCol,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StockBadge(
                          stock: product.stock,
                          minStock: product.minStock,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPriceColumn('PRECIO DE VENTA', CurrencyUtils.format(product.price), primaryCol),
                        if (!isEmpleado) ...[
                          _buildPriceColumn('COSTO', CurrencyUtils.format(product.cost), ColorTokens.lightTextSecondary),
                          _buildPriceColumn('MARGEN', '$marginPct%', ColorTokens.statusSuccess),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPriceColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FontTokens.bodySmall.copyWith(
            fontSize: 10,
            color: ColorTokens.lightTextSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: FontTokens.moneyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}


