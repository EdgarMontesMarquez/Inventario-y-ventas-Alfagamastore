import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/design_system/tokens/color_tokens.dart';
import '../../../../core/design_system/tokens/font_tokens.dart';
import '../../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../../core/design_system/widgets/custom_buttons.dart';
import '../../../../core/design_system/widgets/custom_inputs.dart';
import '../../../../core/design_system/widgets/custom_image_picker.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/sale.dart';
import '../../../../shared/widgets/receipt_modal.dart';
import '../../../../shared/widgets/barcode_scanner_modal.dart';
import '../../../../core/utils/currency_formatter.dart';


class NewSaleSheet extends ConsumerStatefulWidget {
  const NewSaleSheet({super.key});

  @override
  ConsumerState<NewSaleSheet> createState() => _NewSaleSheetState();
}

class _NewSaleSheetState extends ConsumerState<NewSaleSheet> {
  final List<_SaleLineItem> _selectedLines = [];
  String _paymentMethod = 'efectivo';
  String? _receiptImageUrl;
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _stockWarningBanner;

  void _addProductToLines(Product product) {
    setState(() {
      _stockWarningBanner = null;
      if (product.stock <= 0) {
        _stockWarningBanner = 'Producto sin stock disponible (${product.name})';
        return;
      }
      final existingLine = _selectedLines.where((l) => l.product.id == product.id).firstOrNull;
      if (existingLine != null) {
        if (existingLine.qty + 1 > product.stock) {
          _stockWarningBanner = 'Stock máximo disponible alcanzado (${product.stock} unidades)';
          return;
        }
        _updateQty(_selectedLines.indexOf(existingLine), 1);
        return;
      }

      _selectedLines.add(_SaleLineItem(product: product, qty: 1));
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final line = _selectedLines[index];
      final newQty = line.qty + delta;
      if (newQty > line.product.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock máximo alcanzado (${line.product.stock} disponibles)'),
            backgroundColor: ColorTokens.statusWarning,
          ),
        );
        return;
      }
      if (newQty <= 0) {
        _selectedLines.removeAt(index);
      } else {
        line.qty = newQty;
      }
    });
  }

  double get _total => _selectedLines.fold(0.0, (sum, l) => sum + (l.product.price * l.qty));

  void _submitSale() async {
    if (_isSubmitting || _selectedLines.isEmpty) return;

    final activeShift = ref.read(activeCashShiftProvider).asData?.value;
    if (activeShift == null || !activeShift.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe realizar la Apertura de Caja antes de poder registrar ventas.'),
          backgroundColor: ColorTokens.statusWarning,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final saleItems = _selectedLines.map((l) => SaleItem(
        productId: l.product.id,
        productName: l.product.name,
        qty: l.qty,
        unitPrice: l.product.price,
      )).toList();

      final sale = Sale(
        id: const Uuid().v4(),
        items: saleItems,
        total: _total,
        paymentMethod: _paymentMethod,
        createdAt: DateTime.now(),
        note: _noteCtrl.text.trim(),
        receiptImageUrl: _paymentMethod == 'transferencia' ? _receiptImageUrl : null,
      );

      final saleRepo = ref.read(saleRepositoryProvider);
      await saleRepo.addSale(sale);

      ref.invalidate(salesFutureProvider);
      ref.invalidate(productsFutureProvider);
      ref.invalidate(activeCashShiftProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta registrada exitosamente'),
            backgroundColor: ColorTokens.lightBrandPrimary,
          ),
        );
        ReceiptModal.show(context, sale);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsFutureProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_stockWarningBanner != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ColorTokens.warning.withAlpha(25),
                border: Border.all(color: ColorTokens.warning),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: ColorTokens.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stockWarningBanner!,
                      style: FontTokens.bodySmall.copyWith(color: ColorTokens.text, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Búsqueda de Productos con Escáner de Cámara
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Buscar Producto para Agregar',
                  hint: 'Escribe el nombre o SKU…',
                  controller: _searchCtrl,
                  prefixIcon: const Icon(Icons.search, size: 20, color: ColorTokens.textMuted),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorTokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorTokens.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: ColorTokens.primary),
                    tooltip: 'Escanear código de barras para venta',
                    onPressed: () async {
                      final scanned = await BarcodeScannerModal.scan(context);
                      if (scanned != null && mounted) {
                        setState(() {
                          _searchQuery = scanned;
                          _searchCtrl.text = scanned;
                        });
                        // Si coincide exactamente con un producto, agregarlo automáticamente
                        final products = productsAsync.value;
                        if (products != null) {
                          final match = products.where((p) => p.sku.toUpperCase() == scanned.toUpperCase()).firstOrNull;
                          if (match != null && match.stock > 0) {
                            _addProductToLines(match);
                          }
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dropdown de Productos Coincidentes
          if (_searchQuery.trim().isNotEmpty)
            productsAsync.when(
              loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox(),
              data: (products) {
                final available = products.where((p) => p.stock > 0 &&
                    (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                     p.sku.toLowerCase().contains(_searchQuery.toLowerCase()))).toList();

                if (available.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Text('Sin productos con stock', style: FontTokens.bodySmall),
                  );
                }

                return Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: ColorTokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorTokens.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.take(5).length,
                    separatorBuilder: (context, idx) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final p = available[idx];
                      return ListTile(
                        title: Text(p.name, style: FontTokens.bodyMedium),
                        trailing: Text(CurrencyUtils.format(p.price), style: FontTokens.moneySmall.copyWith(color: ColorTokens.primary)),
                        onTap: () => _addProductToLines(p),
                      );
                    },
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // Lista de Items Seleccionados
          if (_selectedLines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Busca y selecciona productos para vender',
                  style: FontTokens.bodySmall.copyWith(color: ColorTokens.textDim),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedLines.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final item = _selectedLines[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ColorTokens.surfaceElevated,
                    border: Border.all(color: ColorTokens.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: FontTokens.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ColorTokens.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.format(item.product.price * item.qty),
                              style: FontTokens.moneyMedium.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: ColorTokens.textMuted),
                        onPressed: () => _updateQty(idx, -1),
                      ),
                      Text('${item.qty}', style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20, color: ColorTokens.primary),
                        onPressed: () => _updateQty(idx, 1),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // Selector de Método de Pago
          Text('MÉTODO DE PAGO', style: FontTokens.label),
          const SizedBox(height: 8),
          Row(
            children: ['efectivo', 'transferencia'].map((m) {
              final isSelected = _paymentMethod == m;
              Color color = m == 'efectivo' ? ColorTokens.primary : ColorTokens.secondary;
              String labelText = m == 'efectivo' ? 'EFECTIVO' : 'TRANSFERENCIA';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _paymentMethod = m;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected ? color.withAlpha(30) : ColorTokens.surfaceElevated,
                      side: BorderSide(color: isSelected ? color : ColorTokens.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      labelText,
                      style: FontTokens.label.copyWith(
                        color: isSelected ? color : ColorTokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_paymentMethod == 'transferencia') ...[
            const SizedBox(height: 14),
            CustomImagePicker(
              initialImageUrl: _receiptImageUrl,
              label: 'Comprobante de Transferencia (Opcional)',
              onImageSelected: (url) {
                setState(() {
                  _receiptImageUrl = url;
                });
              },
            ),
          ],

          const SizedBox(height: 14),
          CustomTextField(
            label: 'Nota (opcional)',
            hint: 'Cliente frecuente, observación…',
            controller: _noteCtrl,
          ),
          const SizedBox(height: 16),

          // Tarjeta del Total con elevación 3D
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorTokens.lightBorderSubtle),
              boxShadow: BorderShadowTokens.shadow3DCard,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL VENTA', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold)),
                Text(
                  CurrencyUtils.format(_total),
                  style: FontTokens.moneyLarge.copyWith(color: ColorTokens.lightBrandPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CustomButton(
            text: 'Registrar venta · ${CurrencyUtils.format(_total)}',
            icon: Icons.check_circle_outline,
            isLoading: _isSubmitting,
            onPressed: _selectedLines.isNotEmpty ? _submitSale : null,
          ),
        ],
      ),
    );
  }
}

class _SaleLineItem {
  final Product product;
  int qty;

  _SaleLineItem({required this.product, required this.qty});
}
