import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/image_viewer_modal.dart';

class PublicCreditLookupScreen extends StatefulWidget {
  final String? initialDocType;
  final String? initialDocId;

  const PublicCreditLookupScreen({
    super.key,
    this.initialDocType,
    this.initialDocId,
  });

  @override
  State<PublicCreditLookupScreen> createState() => _PublicCreditLookupScreenState();
}

class _PublicCreditLookupScreenState extends State<PublicCreditLookupScreen> {
  final TextEditingController _docIdController = TextEditingController();
  String _selectedDocType = 'CC';
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  Map<String, dynamic>? _customerData;
  List<Map<String, dynamic>> _creditsList = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialDocType != null && widget.initialDocType!.isNotEmpty) {
      _selectedDocType = widget.initialDocType!.toUpperCase();
    }
    if (widget.initialDocId != null && widget.initialDocId!.isNotEmpty) {
      _docIdController.text = widget.initialDocId!;
      _performSearch();
    }
  }

  @override
  void dispose() {
    _docIdController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final cleanId = _docIdController.text.trim();
    if (cleanId.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa un número de documento.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
      _customerData = null;
      _creditsList = [];
    });

    try {
      final client = Supabase.instance.client;

      // 1. Buscar cliente por document_id o phone en public.customers
      try {
        final custRes = await client
            .from('customers')
            .select()
            .or('document_id.eq.$cleanId,phone.eq.$cleanId')
            .limit(1)
            .maybeSingle();
        if (custRes != null) {
          _customerData = custRes;
        }
      } catch (_) {}

      // 2. Buscar créditos asociados en public.credits (con credit_installments)
      List<dynamic> creditsRaw = [];

      try {
        if (_customerData != null) {
          final custId = _customerData!['id'];
          final custName = _customerData!['name'] ?? '';
          creditsRaw = await client
              .from('credits')
              .select('*, credit_installments(*)')
              .or('customer_id.eq.$custId,customer_name.ilike.%$custName%,notes.ilike.%$cleanId%')
              .order('created_at', ascending: false);
        } else {
          creditsRaw = await client
              .from('credits')
              .select('*, credit_installments(*)')
              .or('notes.ilike.%$cleanId%,customer_phone.eq.$cleanId,customer_name.ilike.%$cleanId%')
              .order('created_at', ascending: false);
        }
      } catch (_) {}

      // Fallback de resiliencia: Si la consulta con .or(...) falla o retorna vacía, consultar todos los créditos y filtrar localmente
      if (creditsRaw.isEmpty) {
        try {
          final allCredits = await client
              .from('credits')
              .select('*, credit_installments(*)')
              .order('created_at', ascending: false);

          creditsRaw = (allCredits as List).where((c) {
            final String notes = c['notes']?.toString() ?? '';
            final String phone = c['customer_phone']?.toString() ?? '';
            final String name = c['customer_name']?.toString() ?? '';
            final String cId = c['customer_id']?.toString() ?? '';

            if (_customerData != null && cId == _customerData!['id'].toString()) return true;
            if (notes.contains(cleanId)) return true;
            if (phone.contains(cleanId)) return true;
            if (_customerData != null && name.toLowerCase().contains((_customerData!['name'] ?? '').toString().toLowerCase())) return true;
            return false;
          }).toList();
        } catch (_) {}
      }

      setState(() {
        _creditsList = List<Map<String, dynamic>>.from(creditsRaw);
        _isLoading = false;
      });
    } catch (err) {
      setState(() {
        _errorMessage = 'Ocurrió un error al consultar el sistema: ${err.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat("d 'de' MMMM, yyyy", 'es_CO').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: ColorTokens.lightBgPrimary, // #F4F7FF Azul Hielo Polvo
      appBar: AppBar(
        backgroundColor: ColorTokens.lightTextPrimary, // #0A192F Azul Noche
        elevation: 2,
        title: Row(
          children: [
            const AppLogo(size: 38),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALFA GAMA STORE',
                  style: FontTokens.h3.copyWith(color: Colors.white, fontSize: 16),
                ),
                Text(
                  'PORTAL DE CRÉDITOS Y ESTADO DE CUENTA',
                  style: FontTokens.caption.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 850),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Tarjeta Banner de Búsqueda
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ColorTokens.lightBorderSubtle),
                    boxShadow: BorderShadowTokens.shadow3DCard,
                  ),
                  child: Column(
                    children: [
                      // Barra de acento superior en Azul Eléctrico
                      Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          color: ColorTokens.lightBrandPrimary, // #0066FF
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: ColorTokens.lightBrandLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: ColorTokens.lightBrandPrimary.withAlpha(76)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 14, color: ColorTokens.lightBrandPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Consulta de Estado de Cuenta en Tiempo Real',
                                    style: FontTokens.caption.copyWith(
                                      color: ColorTokens.lightBrandPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Consulta tu Historial de Crédito',
                              textAlign: TextAlign.center,
                              style: FontTokens.h2.copyWith(color: ColorTokens.lightTextPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ingresa tu tipo y número de documento registrado para consultar saldos, fechas de vencimiento y recibos de abonos.',
                              textAlign: TextAlign.center,
                              style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
                            ),
                            const SizedBox(height: 24),

                            // Formulario de Búsqueda
                            Flex(
                              direction: isDesktop ? Axis.horizontal : Axis.vertical,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Selector Tipo Documento
                                SizedBox(
                                  width: isDesktop ? 180 : double.infinity,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TIPO DOC.',
                                        style: FontTokens.label.copyWith(
                                          color: ColorTokens.lightTextSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedDocType,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle),
                                          ),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'CC', child: Text('Cédula (CC)')),
                                          DropdownMenuItem(value: 'CE', child: Text('Extranjería (CE)')),
                                          DropdownMenuItem(value: 'NIT', child: Text('NIT / RUT')),
                                          DropdownMenuItem(value: 'PAS', child: Text('Pasaporte')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedDocType = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 12 : 0, height: isDesktop ? 0 : 12),

                                // Campo Número Documento
                                Expanded(
                                  flex: isDesktop ? 1 : 0,
                                  child: SizedBox(
                                    width: isDesktop ? null : double.infinity,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'NÚMERO DE DOCUMENTO',
                                          style: FontTokens.label.copyWith(
                                            color: ColorTokens.lightTextSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _docIdController,
                                          keyboardType: TextInputType.text,
                                          onSubmitted: (_) => _performSearch(),
                                          decoration: InputDecoration(
                                            hintText: 'Ej: 1107858381',
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: ColorTokens.lightBrandPrimary, width: 2),
                                            ),
                                            suffixIcon: _docIdController.text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(Icons.clear, size: 18),
                                                    onPressed: () {
                                                      _docIdController.clear();
                                                      setState(() {});
                                                    },
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 12 : 0, height: isDesktop ? 0 : 16),

                                // Botón Consultar
                                SizedBox(
                                  width: isDesktop ? 160 : double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _performSearch,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.search, size: 20),
                                    label: Text(
                                      _isLoading ? 'Buscando...' : 'Consultar',
                                      style: FontTokens.button.copyWith(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ColorTokens.lightBrandPrimary, // #0066FF
                                      foregroundColor: Colors.white,
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: ColorTokens.statusDangerDim,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ColorTokens.statusDanger.withAlpha(76)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: ColorTokens.statusDanger, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: FontTokens.bodySmall.copyWith(color: ColorTokens.statusDanger, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Resultados de la Búsqueda
                if (_hasSearched && !_isLoading) ...[
                  if (_creditsList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ColorTokens.lightBorderSubtle),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ColorTokens.lightBgPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: ColorTokens.lightBorderSubtle),
                            ),
                            child: const Icon(Icons.credit_card_off_outlined, size: 40, color: ColorTokens.lightBrandPrimary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sin créditos registrados',
                            style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No se encontraron créditos asociados al documento $_selectedDocType ${_docIdController.text}. Verifica el número ingresado o comunícate con la tienda.',
                            textAlign: TextAlign.center,
                            style: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextSecondary),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Tarjeta Titular del Cliente
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ColorTokens.lightBorderSubtle),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: ColorTokens.lightBrandLight,
                            child: Icon(Icons.person, color: ColorTokens.lightBrandPrimary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TITULAR DEL CRÉDITO',
                                  style: FontTokens.label.copyWith(color: ColorTokens.lightBrandPrimary, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _customerData?['name'] ?? _creditsList.first['customer_name'] ?? 'Cliente AlfaGama',
                                  style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary),
                                ),
                                Text(
                                  'DOCUMENTO: $_selectedDocType ${_docIdController.text}',
                                  style: FontTokens.caption.copyWith(color: ColorTokens.lightTextSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lista de Créditos
                    ..._creditsList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final credit = entry.value;

                      final double totalAmt = (credit['total_amount'] as num? ?? 0).toDouble();
                      final double paidAmt = (credit['paid_amount'] as num? ?? 0).toDouble();
                      final double pendingBalance = (totalAmt - paidAmt).clamp(0, double.infinity);
                      final bool isPaidFull = pendingBalance <= 0 || credit['status'] == 'finalizado';
                      final bool isMora = credit['status'] == 'mora';
                      final double progressPct = totalAmt > 0 ? (paidAmt / totalAmt).clamp(0.0, 1.0) : 0.0;

                      final installments = (credit['credit_installments'] as List? ?? []);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ColorTokens.lightBorderSubtle),
                          boxShadow: BorderShadowTokens.shadow3DCard,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header del Crédito
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: ColorTokens.lightBgPrimary.withAlpha(153),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Crédito #${_creditsList.length - idx}',
                                            style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isPaidFull
                                                  ? ColorTokens.statusSuccessDim
                                                  : isMora
                                                      ? ColorTokens.statusDangerDim
                                                      : ColorTokens.statusInfoDim,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isPaidFull
                                                    ? ColorTokens.statusSuccess
                                                    : isMora
                                                        ? ColorTokens.statusDanger
                                                        : ColorTokens.lightBrandPrimary,
                                              ),
                                            ),
                                            child: Text(
                                              isPaidFull ? 'FINALIZADO' : isMora ? 'EN MORA' : 'AL DÍA',
                                              style: FontTokens.label.copyWith(
                                                color: isPaidFull
                                                    ? ColorTokens.statusSuccess
                                                    : isMora
                                                        ? ColorTokens.statusDanger
                                                        : ColorTokens.lightBrandPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'REGISTRADO EL ${_formatDate(credit['created_at'])} · ${credit['products'] ?? 'Productos Varios'}',
                                        style: FontTokens.caption.copyWith(color: ColorTokens.lightTextSecondary),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'SALDO PENDIENTE',
                                        style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary),
                                      ),
                                      Text(
                                        CurrencyUtils.format(pendingBalance),
                                        style: FontTokens.h2.copyWith(
                                          color: pendingBalance > 0 ? ColorTokens.lightBrandPrimary : ColorTokens.statusSuccess,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Barra de Progreso
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Progreso del Pago (${(progressPct * 100).toStringAsFixed(0)}%)',
                                        style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${CurrencyUtils.format(paidAmt)} de ${CurrencyUtils.format(totalAmt)}',
                                        style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextPrimary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progressPct,
                                      minHeight: 10,
                                      backgroundColor: ColorTokens.lightBgSecondary,
                                      color: isPaidFull ? ColorTokens.statusSuccess : ColorTokens.lightBrandPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Desglose de Métricas Resumen
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: GridView.count(
                                crossAxisCount: isDesktop ? 4 : 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2.5,
                                children: [
                                  _buildMetricTile('MONTO TOTAL', CurrencyUtils.format(totalAmt)),
                                  _buildMetricTile('TOTAL ABONADO', CurrencyUtils.format(paidAmt), isSuccess: true),
                                  _buildMetricTile('CUOTAS', '${credit['installments_count'] ?? 1} (${credit['payment_frequency'] ?? 'mensual'})'),
                                  _buildMetricTile('VENCIMIENTO', _formatDate(credit['due_date'])),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Tabla de Cuotas
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 18, color: ColorTokens.lightBrandPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Plan de Cuotas e Historial de Abonos',
                                        style: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (installments.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: ColorTokens.lightBgPrimary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'No hay desglose de cuotas registrado.',
                                        style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: ColorTokens.lightBorderSubtle),
                                      ),
                                      child: Column(
                                        children: [
                                          // Header de Tabla
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            color: ColorTokens.lightBgPrimary,
                                            child: Row(
                                              children: [
                                                Expanded(flex: 2, child: Text('Cuota #', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 3, child: Text('Vencimiento', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 3, child: Text('Monto Cuota', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 3, child: Text('Estado', style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 2, child: Text('Comprobante', textAlign: TextAlign.right, style: FontTokens.label.copyWith(color: ColorTokens.lightTextSecondary, fontWeight: FontWeight.bold))),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 1),

                                          // Filas de Cuotas
                                          ...installments.map((inst) {
                                            final bool isPaid = inst['is_paid'] == true;
                                            final String? receiptUrl = inst['receipt_image_url'];
                                            final bool hasReceipt = receiptUrl != null && receiptUrl.trim().isNotEmpty;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: ColorTokens.lightBorderSubtle)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 2, child: Text('Cuota #${inst['number']}', style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
                                                  Expanded(flex: 3, child: Text(_formatDate(inst['due_date']), style: FontTokens.bodySmall)),
                                                  Expanded(flex: 3, child: Text(CurrencyUtils.format((inst['amount'] as num? ?? 0).toDouble()), style: FontTokens.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          isPaid ? Icons.check_circle : Icons.pending_actions,
                                                          size: 16,
                                                          color: isPaid ? ColorTokens.statusSuccess : ColorTokens.statusWarning,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          isPaid ? 'Pagado' : 'Pendiente',
                                                          style: FontTokens.caption.copyWith(
                                                            color: isPaid ? ColorTokens.statusSuccess : ColorTokens.statusWarning,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Align(
                                                      alignment: Alignment.centerRight,
                                                      child: hasReceipt
                                                          ? IconButton(
                                                              icon: const Icon(Icons.visibility, color: ColorTokens.lightBrandPrimary, size: 20),
                                                              onPressed: () {
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (_) => ImageViewerModal(
                                                                    imageUrl: receiptUrl,
                                                                    title: 'Comprobante Cuota #${inst['number']}',
                                                                  ),
                                                                );
                                                              },
                                                            )
                                                          : Text('-', style: FontTokens.caption.copyWith(color: ColorTokens.lightTextDisabled)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, {bool isSuccess = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorTokens.lightBgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorTokens.lightBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: FontTokens.caption.copyWith(color: ColorTokens.lightTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value,
            style: FontTokens.h3.copyWith(
              color: isSuccess ? ColorTokens.statusSuccess : ColorTokens.lightTextPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
