import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../core/design_system/widgets/custom_overlays.dart';
import '../../../shared/models/credit.dart';
import '../../../shared/models/customer.dart';
import '../../../shared/models/product.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/credit_card.dart';
import '../../../shared/widgets/barcode_scanner_modal.dart';
import '../../../core/utils/currency_formatter.dart';

import '../../auth/providers/auth_provider.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  void _openNewCreditSheet(BuildContext context, WidgetRef ref) {
    if (ref.read(authProvider).isEmpleado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo el Administrador puede aperturar nuevos créditos.'),
          backgroundColor: ColorTokens.statusWarning,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Nuevo crédito',
      child: _NewCreditSheet(
        onSave: (credit) async {
          final repo = ref.read(creditRepositoryProvider);
          await repo.addCredit(credit);
          ref.invalidate(creditsFutureProvider);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Crédito registrado exitosamente'),
                backgroundColor: ColorTokens.lightBrandPrimary,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsFutureProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos & Cobranza'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 22, color: ColorTokens.lightBrandPrimary),
            onPressed: () {
              context.push('/customers');
            },
            tooltip: 'Directorio de Clientes / Crear Cliente',
          ),
        ],
      ),
      floatingActionButton: authState.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openNewCreditSheet(context, ref),
              backgroundColor: ColorTokens.lightBrandPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo Crédito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: creditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar créditos: $err')),
        data: (credits) {
          if (credits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_score_outlined, size: 64, color: ColorTokens.textMuted),
                  const SizedBox(height: 16),
                  Text('No hay créditos registrados', style: FontTokens.h3),
                  const SizedBox(height: 8),
                  Text('Toca "+" para crear un nuevo crédito a cuotas.', style: FontTokens.bodySmall),
                ],
              ),
            );
          }

          final totalPorCobrar = credits.fold(0.0, (sum, c) => sum + c.pendingBalance);
          final totalCobrado = credits.fold(0.0, (sum, c) => sum + c.totalPaid);
          final morososCount = credits.where((c) => c.status == 'mora').length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creditsFutureProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Header Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColorTokens.surface,
                            border: Border.all(color: ColorTokens.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('COBRADO (RECAUDO)', style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.primary)),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyUtils.format(totalCobrado),
                                style: FontTokens.bodyMedium.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColorTokens.surface,
                            border: Border.all(color: ColorTokens.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('POR COBRAR (SALDO)', style: FontTokens.label.copyWith(fontSize: 8, color: ColorTokens.warning)),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyUtils.format(totalPorCobrar),
                                style: FontTokens.bodyMedium.copyWith(color: ColorTokens.warning, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColorTokens.surface,
                            border: Border.all(color: ColorTokens.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EN MORA', style: FontTokens.label.copyWith(fontSize: 8)),
                              const SizedBox(height: 4),
                              Text(
                                '$morososCount cliente(s)',
                                style: FontTokens.bodyMedium.copyWith(
                                  color: morososCount > 0 ? ColorTokens.error : ColorTokens.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Lista de Créditos
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: credits.length,
                    separatorBuilder: (context, idx) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final credit = credits[idx];
                      return CreditCard(
                        credit: credit,
                        onTap: () {
                          context.push('/credits/${credit.id}');
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewCreditSheet extends ConsumerStatefulWidget {
  final ValueChanged<Credit> onSave;

  const _NewCreditSheet({required this.onSave});

  @override
  ConsumerState<_NewCreditSheet> createState() => _NewCreditSheetState();
}

class _NewCreditSheetState extends ConsumerState<_NewCreditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _docIdCtrl = TextEditingController();
  final _productsCtrl = TextEditingController();
  final _totalSaleCtrl = TextEditingController();
  final _totalQuotasCtrl = TextEditingController();
  final _customInterestCtrl = TextEditingController(text: '0');
  final _customQuotaCtrl = TextEditingController();

  String _docType = 'CC';
  String _frequency = 'mensual';
  final DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _docIdCtrl.dispose();
    _productsCtrl.dispose();
    _totalSaleCtrl.dispose();
    _totalQuotasCtrl.dispose();
    _customInterestCtrl.dispose();
    _customQuotaCtrl.dispose();
    super.dispose();
  }

  double get _baseSale => double.tryParse(_totalSaleCtrl.text) ?? 0;
  double get _interestRate => double.tryParse(_customInterestCtrl.text) ?? 0;
  double get _interestAmount => _baseSale * (_interestRate / 100);
  double get _totalWithInterest => _baseSale + _interestAmount;

  double get _quotaValue {
    final manualQuota = double.tryParse(_customQuotaCtrl.text);
    if (manualQuota != null && manualQuota > 0) return manualQuota;

    final quotas = int.tryParse(_totalQuotasCtrl.text) ?? 0;
    if (_totalWithInterest > 0 && quotas > 0) {
      return (_totalWithInterest / quotas).ceilToDouble();
    }
    return 0;
  }

  Product? _matchedProduct;
  bool _isSubmitting = false;

  TextEditingController? _customerTextCtrl;
  TextEditingController? _productTextCtrl;

  void _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final totalQuotas = int.tryParse(_totalQuotasCtrl.text) ?? 0;

      final productText = _productTextCtrl?.text.trim() ?? _productsCtrl.text.trim();
      final customerText = _customerTextCtrl?.text.trim() ?? _nameCtrl.text.trim();

      // Validar si el cliente ya posee un crédito activo
      final existingCredits = ref.read(creditsFutureProvider).asData?.value ?? [];
      final activeCredit = existingCredits.where((c) =>
          (c.clientName.trim().toLowerCase() == customerText.trim().toLowerCase() ||
           (_docIdCtrl.text.trim().isNotEmpty && c.generalNotes.contains(_docIdCtrl.text.trim()))) &&
          c.status != 'finalizado'
      ).firstOrNull;

      if (activeCredit != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El cliente "$customerText" ya tiene un crédito activo. Debe finalizarlo antes de abrir uno nuevo.'),
            backgroundColor: ColorTokens.statusWarning,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Intentar vincular producto de inventario por nombre o SKU si _matchedProduct es null
      final productsList = ref.read(productsFutureProvider).asData?.value ?? [];
      if (_matchedProduct == null && productText.isNotEmpty) {
        _matchedProduct = productsList.where((p) =>
            p.name.toLowerCase() == productText.toLowerCase() ||
            p.sku.toLowerCase() == productText.toLowerCase()).firstOrNull;
      }

      final installments = Credit.generateInstallments(
        _startDate,
        _frequency,
        totalQuotas,
        _quotaValue,
      );

      final credit = Credit(
        id: const Uuid().v4(),
        clientName: customerText,
        clientPhone: _phoneCtrl.text.trim(),
        clientAddress: _addressCtrl.text.trim(),
        products: productText,
        totalSale: _totalWithInterest,
        startDate: _startDate,
        paymentFrequency: _frequency,
        totalQuotas: totalQuotas,
        quotaValue: _quotaValue,
        installments: installments,
        generalNotes: 'Documento: $_docType ${_docIdCtrl.text.trim()} | Interés: ${_interestRate.toStringAsFixed(1)}%',
      );

      // Descontar 1 unidad de stock en Supabase si el producto está en el inventario
      if (_matchedProduct != null) {
        try {
          final productRepo = ref.read(productRepositoryProvider);
          await productRepo.sellProduct(_matchedProduct!.id, 1);
          ref.invalidate(productsFutureProvider);
        } catch (_) {}
      }

      widget.onSave(credit);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _customerQuery = '';
  String _productQuery = '';
  bool _showCustomerResults = false;
  bool _showProductResults = false;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final customersAsync = ref.watch(customersFutureProvider);
    final productsAsync = ref.watch(productsFutureProvider);

    final registeredCustomers = customersAsync.asData?.value ?? [];
    final productsList = productsAsync.asData?.value ?? [];

    final matchingCustomers = _customerQuery.trim().isEmpty
        ? <Customer>[]
        : registeredCustomers.where((c) =>
            c.name.toLowerCase().contains(_customerQuery.toLowerCase()) ||
            c.documentId.contains(_customerQuery)).toList();

    final matchingProducts = _productQuery.trim().isEmpty
        ? <Product>[]
        : productsList.where((p) =>
            p.name.toLowerCase().contains(_productQuery.toLowerCase()) ||
            p.sku.toLowerCase().contains(_productQuery.toLowerCase())).toList();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buscador de Clientes
            CustomTextField(
              label: 'Nombre del Cliente (Escribe para buscar)',
              hint: 'Escribe nombre o documento CC…',
              controller: _nameCtrl,
              onChanged: (val) {
                setState(() {
                  _customerQuery = val;
                  _showCustomerResults = true;
                });
              },
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),

            if (_showCustomerResults && matchingCustomers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceElevated,
                  border: Border.all(color: ColorTokens.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matchingCustomers.length,
                  separatorBuilder: (ctx, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final c = matchingCustomers[idx];
                    return ListTile(
                      dense: true,
                      title: Text(c.name, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('${c.documentType}: ${c.documentId} · Tel: ${c.phone}', style: FontTokens.bodySmall),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: ColorTokens.primary),
                      onTap: () {
                        setState(() {
                          _nameCtrl.text = c.name;
                          _phoneCtrl.text = c.phone;
                          _addressCtrl.text = c.address;
                          _docIdCtrl.text = c.documentId;
                          _docType = c.documentType;
                          _customerQuery = '';
                          _showCustomerResults = false;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Tipo y Número de Documento Identificación
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIPO',
                        style: FontTokens.bodySmall.copyWith(
                          color: ColorTokens.lightTextSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _docType,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'CC', child: Text('CC')),
                          DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                          DropdownMenuItem(value: 'CE', child: Text('CE')),
                          DropdownMenuItem(value: 'Pasaporte', child: Text('PAS')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _docType = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: CustomTextField(
                    label: 'N° Documento (Único)',
                    hint: '1098765432',
                    controller: _docIdCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: CustomPhoneInput(
                    label: 'Teléfono',
                    hint: '300 123 4567',
                    controller: _phoneCtrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Dirección',
                    hint: 'Cra 5 #12-34',
                    controller: _addressCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Buscador de Productos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Producto(s) (Escribe o Escanea)',
                    hint: 'Escribe nombre o SKU del producto…',
                    controller: _productsCtrl,
                    onChanged: (val) {
                      setState(() {
                        _productQuery = val;
                        _showProductResults = true;
                        _matchedProduct = null;
                      });
                    },
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: ColorTokens.primary, size: 24),
                    tooltip: 'Escanear producto con cámara',
                    onPressed: () async {
                      final sku = await BarcodeScannerModal.scan(context);
                      if (sku != null && mounted) {
                        final found = productsList.where((p) => p.sku.toLowerCase() == sku.toLowerCase()).firstOrNull;
                        if (found != null) {
                          _productsCtrl.text = found.name;
                          _totalSaleCtrl.text = found.price.toStringAsFixed(0);
                          _matchedProduct = found;
                        } else {
                          _productsCtrl.text = 'SKU: $sku';
                          _matchedProduct = null;
                        }
                        setState(() {
                          _showProductResults = false;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            if (_showProductResults && matchingProducts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceElevated,
                  border: Border.all(color: ColorTokens.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matchingProducts.length,
                  separatorBuilder: (ctx, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final p = matchingProducts[idx];
                    return ListTile(
                      dense: true,
                      title: Text(p.name, style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('SKU: ${p.sku} · Stock: ${p.stock} uds', style: FontTokens.bodySmall),
                      trailing: Text(currencyFmt.format(p.price), style: FontTokens.moneySmall.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold)),
                      onTap: () {
                        setState(() {
                          _productsCtrl.text = p.name;
                          _totalSaleCtrl.text = p.price.toStringAsFixed(0);
                          _matchedProduct = p;
                          _productQuery = '';
                          _showProductResults = false;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: CustomMoneyInput(
                    label: 'Total Venta',
                    hint: '3200000',
                    controller: _totalSaleCtrl,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'N° Cuotas',
                    hint: '12',
                    controller: _totalQuotasCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FRECUENCIA DE PAGO',
                        style: FontTokens.bodySmall.copyWith(
                          color: ColorTokens.lightTextSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                          DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                          DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                          DropdownMenuItem(value: 'diario', child: Text('Diario')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _frequency = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Tasa Interés (%)',
                    hint: '5',
                    controller: _customInterestCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            CustomMoneyInput(
              label: 'Valor por Cuota (Personalizable)',
              hint: 'Ingresa o edita el valor de la cuota',
              controller: _customQuotaCtrl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            if (_quotaValue > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorTokens.primary.withAlpha(20),
                  border: Border.all(color: ColorTokens.primary.withAlpha(60)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('VALOR POR CUOTA:', style: FontTokens.label.copyWith(fontSize: 11)),
                    Text(
                      currencyFmt.format(_quotaValue),
                      style: FontTokens.h3.copyWith(color: ColorTokens.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            CustomButton(
              text: 'Registrar Crédito',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
