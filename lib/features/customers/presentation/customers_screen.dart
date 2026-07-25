import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../core/design_system/widgets/custom_progress.dart';
import '../../../core/design_system/widgets/custom_overlays.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/models/customer.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';


class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  void _openNewCustomerSheet() {
    CustomOverlays.showBottomSheet(
      context: context,
      title: 'Nuevo cliente',
      child: _NewCustomerSheet(
        onSave: (customer) async {
          final repo = ref.read(customerRepositoryProvider);
          await repo.addCustomer(customer);
          ref.invalidate(customersFutureProvider);
          ref.read(customersFutureProvider);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cliente guardado exitosamente'),
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
    ref.listen(customersFutureProvider, (previous, next) {});
    final customersAsync = ref.watch(customersFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersFutureProvider);
          await ref.read(customersFutureProvider.future);
        },
        backgroundColor: Colors.white,
        color: ColorTokens.lightBrandPrimary,
        child: customersAsync.when(
          loading: () => const LoadingSpinner(message: 'Cargando directorio de clientes...'),
          error: (err, stack) => ErrorState(
            title: 'Error al cargar clientes',
            message: err.toString(),
            onRetry: () => ref.invalidate(customersFutureProvider),
          ),
          data: (customers) {
            final filtered = customers.where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.phone.contains(_searchQuery)).toList();

            return Column(
              children: [
                Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DIRECTORIO', style: FontTokens.label.copyWith(color: ColorTokens.textMuted)),
                            Text('${customers.length} clientes', style: FontTokens.h2),
                          ],
                        ),
                        if (ref.watch(authProvider).isAdmin)
                          CustomButton(
                            text: 'Nuevo',
                            icon: Icons.person_add_alt_1,
                            isFullWidth: false,
                            onPressed: _openNewCustomerSheet,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: '',
                      hint: 'Buscar por nombre o teléfono…',
                      prefixIcon: const Icon(Icons.search, size: 20, color: ColorTokens.textMuted),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        title: 'Sin clientes',
                        description: 'No se encontraron clientes con el filtro ingresado.',
                        icon: Icons.people_outline,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, idx) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ColorTokens.surface,
                              border: Border.all(color: ColorTokens.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: ColorTokens.surfaceElevated,
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                    style: FontTokens.h3.copyWith(color: ColorTokens.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: FontTokens.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: ColorTokens.textDim),
                                          const SizedBox(width: 4),
                                          Text(c.phone, style: FontTokens.bodySmall.copyWith(color: ColorTokens.textMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('CRÉDITO ACTIVO', style: FontTokens.label.copyWith(fontSize: 8)),
                                    Text(
                                      CurrencyUtils.format(c.activeCreditBalance),
                                      style: FontTokens.moneySmall.copyWith(
                                        color: c.activeCreditBalance > 0 ? ColorTokens.secondary : ColorTokens.textDim,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
}

class _NewCustomerSheet extends StatefulWidget {
  final ValueChanged<Customer> onSave;

  const _NewCustomerSheet({required this.onSave});

  @override
  State<_NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends State<_NewCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _docIdCtrl = TextEditingController();
  String _docType = 'CC';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _docIdCtrl.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  void _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final customer = Customer(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        documentType: _docType,
        documentId: _docIdCtrl.text.trim().isNotEmpty
            ? _docIdCtrl.text.trim()
            : DateTime.now().millisecondsSinceEpoch.toString(),
        totalPurchases: 0,
        activeCreditBalance: 0,
        createdAt: DateTime.now(),
      );

      widget.onSave(customer);
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
    return Form(
      key: _formKey,
      child: Column(
        children: [
          CustomTextField(
            label: 'Nombre Completo',
            hint: 'Edgar Montes',
            controller: _nameCtrl,
            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _docType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo Doc.'),
                  items: const [
                    DropdownMenuItem(value: 'CC', child: Text('CC')),
                    DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                    DropdownMenuItem(value: 'CE', child: Text('CE')),
                    DropdownMenuItem(value: 'Pasaporte', child: Text('Pasaporte')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _docType = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: CustomTextField(
                  label: 'N° Documento Identificación',
                  hint: '1108758381',
                  controller: _docIdCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          CustomPhoneInput(
            label: 'Teléfono',
            hint: '3004375191',
            controller: _phoneCtrl,
            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Dirección (opcional)',
            hint: 'Barrio La Siria',
            controller: _addressCtrl,
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Guardar cliente',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
