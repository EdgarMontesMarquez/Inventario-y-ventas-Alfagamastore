import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../core/design_system/widgets/custom_overlays.dart';
import '../../../core/design_system/widgets/custom_image_picker.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/barcode_scanner_modal.dart';
import '../../../shared/widgets/barcode_generator_modal.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/models/product.dart';
import '../providers/category_provider.dart';
import '../../auth/providers/auth_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  void _openProductForm([Product? initialProduct]) {
    CustomOverlays.showBottomSheet(
      context: context,
      title: initialProduct != null ? 'Editar producto' : 'Nuevo producto',
      child: _ProductFormSheet(
        initialProduct: initialProduct,
        onSave: (product) async {
          final repo = ref.read(productRepositoryProvider);
          if (initialProduct != null) {
            await repo.updateProduct(product);
          } else {
            await repo.addProduct(product);
          }
          ref.invalidate(productsFutureProvider);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(initialProduct != null
                    ? 'Producto actualizado exitosamente'
                    : 'Producto registrado exitosamente'),
                backgroundColor: ColorTokens.lightBrandPrimary,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsFutureProvider);
    final categories = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
      ),
      body: productsAsync.when(
        loading: () => const LoadingSpinner(message: 'Cargando inventario...'),
        error: (err, stack) => ErrorState(
          title: 'Error al cargar productos',
          message: err.toString(),
          onRetry: () => ref.invalidate(productsFutureProvider),
        ),
        data: (products) {
          final filtered = products.where((p) {
            final matchesQuery = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCat = _selectedCategory == 'Todos' || p.category == _selectedCategory;
            return matchesQuery && matchesCat;
          }).toList();

          return Column(
            children: [
              // Header & Add Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INVENTARIO',
                              style: FontTokens.label.copyWith(color: ColorTokens.textMuted),
                            ),
                            Text(
                              '${products.length} productos',
                              style: FontTokens.h2,
                            ),
                          ],
                        ),
                        if (!ref.watch(authProvider).isEmpleado)
                          CustomButton(
                            text: 'Agregar',
                            icon: Icons.add,
                            isFullWidth: false,
                            onPressed: () => _openProductForm(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search Bar Input with Camera Barcode Scanner Suffix
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hint: 'Buscar producto o SKU…',
                            prefixIcon: const Icon(Icons.search, size: 20, color: ColorTokens.textMuted),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: ColorTokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ColorTokens.border),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: ColorTokens.primary),
                            tooltip: 'Escanear código de barras',
                            onPressed: () async {
                              final scanned = await BarcodeScannerModal.scan(context);
                              if (scanned != null && mounted) {
                                setState(() {
                                  _searchQuery = scanned;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Categories Horizontal Filter
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF0A192F),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                            selectedColor: ColorTokens.lightBrandPrimary,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF0A192F),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? ColorTokens.lightBrandPrimary : ColorTokens.lightBorderSubtle,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Product List
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        title: 'Sin resultados',
                        description: 'No se encontraron productos con los criterios ingresados.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return ProductCard(
                            product: product,
                            isEmpleado: ref.watch(authProvider).isEmpleado,
                            onTap: ref.watch(authProvider).isEmpleado ? () {} : () => _openProductForm(product),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  final Product? initialProduct;
  final ValueChanged<Product> onSave;

  const _ProductFormSheet({
    this.initialProduct,
    required this.onSave,
  });

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late String _category;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _priceCtrl = TextEditingController(text: p?.price != null ? p!.price.toInt().toString() : '');
    _costCtrl = TextEditingController(text: p?.cost != null ? p!.cost.toInt().toString() : '');
    _stockCtrl = TextEditingController(text: p?.stock != null ? p!.stock.toString() : '');
    _minStockCtrl = TextEditingController(text: p?.minStock != null ? p!.minStock.toString() : '5');
    _category = p?.category ?? 'Sin categoría';
    _imageUrl = p?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nueva Categoría', style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: ColorTokens.lightTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Nombre de Categoría',
                hint: 'Ej. Calzado, Cosméticos…',
                controller: catCtrl,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: Text('Cancelar', style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextSecondary)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 8),
                  CustomButton(
                    text: 'Agregar',
                    icon: Icons.add,
                    isFullWidth: false,
                    onPressed: () {
                      final newCat = catCtrl.text.trim();
                      if (newCat.isNotEmpty) {
                        ref.read(categoryProvider.notifier).addCategory(newCat);
                        setState(() {
                          _category = newCat;
                        });
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSubmitting = false;
  String? _skuError;

  void _validateSkuInstant(String targetSku) {
    final cleanSku = targetSku.trim().toUpperCase();
    if (cleanSku.isEmpty) {
      setState(() { _skuError = null; });
      return;
    }

    final existingProducts = ref.read(productsFutureProvider).asData?.value ?? [];
    final duplicate = existingProducts.where((p) =>
      p.sku.toUpperCase() == cleanSku && p.id != widget.initialProduct?.id
    ).firstOrNull;

    if (duplicate != null) {
      setState(() {
        _skuError = 'El código de barras (SKU) "$cleanSku" ya pertenece a: ${duplicate.name}';
      });
    } else {
      setState(() {
        _skuError = null;
      });
    }
  }

  void _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final targetSku = _skuCtrl.text.trim().toUpperCase();
    _validateSkuInstant(targetSku);

    if (_skuError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_skuError!),
          backgroundColor: ColorTokens.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final product = Product(
        id: widget.initialProduct?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        sku: targetSku,
        price: double.tryParse(_priceCtrl.text) ?? 0,
        cost: double.tryParse(_costCtrl.text) ?? 0,
        stock: int.tryParse(_stockCtrl.text) ?? 0,
        minStock: int.tryParse(_minStockCtrl.text) ?? 5,
        category: _category,
        imageUrl: _imageUrl,
      );

      widget.onSave(product);
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
    final categories = ref.watch(categoryProvider).where((c) => c != 'Todos').toList();
    if (!categories.contains(_category)) {
      categories.add(_category);
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_skuError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ColorTokens.error.withAlpha(25),
                border: Border.all(color: ColorTokens.error),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _skuError!,
                style: FontTokens.bodySmall.copyWith(color: ColorTokens.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          CustomTextField(
            label: 'Nombre del Producto',
            hint: 'Ej. Arroz Superior 1kg',
            controller: _nameCtrl,
            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'SKU / Código de Barras',
                  hint: 'ARR-001',
                  controller: _skuCtrl,
                  onChanged: (val) => _validateSkuInstant(val),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_2, color: ColorTokens.primary, size: 20),
                        tooltip: 'Generar etiqueta de barras',
                        onPressed: () async {
                          final generatedSku = await BarcodeGeneratorModal.show(
                            context,
                            productName: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Producto Nuevo',
                            sku: _skuCtrl.text,
                            price: double.tryParse(_priceCtrl.text) ?? 0.0,
                          );
                          if (generatedSku != null && mounted) {
                            _skuCtrl.text = generatedSku.toString();
                            _validateSkuInstant(generatedSku.toString());
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: ColorTokens.primary, size: 20),
                        tooltip: 'Escanear con cámara',
                        onPressed: () async {
                          final scanned = await BarcodeScannerModal.scan(context);
                          if (scanned != null && mounted) {
                            _skuCtrl.text = scanned;
                            _validateSkuInstant(scanned);
                          }
                        },
                      ),
                    ],
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CATEGORÍA', style: FontTokens.label),
                        GestureDetector(
                          onTap: _showAddCategoryDialog,
                          child: Text('+ Crear', style: FontTokens.label.copyWith(color: ColorTokens.primary, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.w600),
                      iconEnabledColor: ColorTokens.lightBrandPrimary,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle),
                        ),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            overflow: TextOverflow.ellipsis,
                            style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _category = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomMoneyInput(
                  label: 'Precio Venta',
                  hint: '1850',
                  controller: _priceCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomMoneyInput(
                  label: 'Costo',
                  hint: '1100',
                  controller: _costCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Stock Actual',
                  hint: '10',
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  label: 'Stock Mínimo',
                  hint: '5',
                  controller: _minStockCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomImagePicker(
            initialImageUrl: _imageUrl,
            label: 'Imagen del Producto (Opcional)',
            onImageSelected: (url) {
              setState(() {
                _imageUrl = url;
              });
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: widget.initialProduct != null ? 'Guardar cambios' : 'Agregar producto',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
