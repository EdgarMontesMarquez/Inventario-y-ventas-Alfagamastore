import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/credit.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../core/design_system/widgets/custom_badges.dart';
import '../../core/utils/currency_formatter.dart';


class InstallmentTable extends StatelessWidget {
  final List<CreditInstallment> installments;
  final double totalSale;

  const InstallmentTable({
    super.key,
    required this.installments,
    required this.totalSale,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? ColorTokens.darkSurfacePrimary : ColorTokens.lightSurfacePrimary;
    final borderCol = isDark ? ColorTokens.darkBorderSubtle : ColorTokens.lightBorderSubtle;
    final headerBg = isDark ? ColorTokens.darkBgTertiary : ColorTokens.lightBgTertiary;
    final textMuted = isDark ? ColorTokens.darkTextSecondary : ColorTokens.lightTextSecondary;

    final dateFmt = DateFormat('dd/MM/yyyy');

    double runningBal = totalSale;
    final List<_RowData> rows = [];
    for (var inst in installments) {
      runningBal -= inst.paidAmount;
      rows.add(_RowData(inst: inst, balance: runningBal < 0 ? 0 : runningBal));
    }
    final isCreditFullyPaid = runningBal <= 0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
        boxShadow: BorderShadowTokens.shadowLevel1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: headerBg,
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 16, color: isDark ? ColorTokens.darkBrandPrimary : ColorTokens.lightBrandPrimary),
                const SizedBox(width: 8),
                Text(
                  'PLAN DE AMORTIZACIÓN Y CUOTAS',
                  style: FontTokens.label.copyWith(
                    color: isDark ? ColorTokens.darkTextPrimary : ColorTokens.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(headerBg),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columnSpacing: 18,
              horizontalMargin: 16,
              headingTextStyle: FontTokens.bodySmall.copyWith(color: textMuted, fontWeight: FontWeight.bold),
              columns: const [
                DataColumn(label: Text('N°')),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Cuota')),
                DataColumn(label: Text('Abono')),
                DataColumn(label: Text('Saldo')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Obs.')),
              ],
              rows: List.generate(rows.length, (index) {
                final row = rows[index];
                final inst = row.inst;
                final s = isCreditFullyPaid ? 'pagado' : inst.status;
                final isEven = index % 2 == 0;

                final rowColor = isEven
                    ? cardBg
                    : (isDark ? ColorTokens.darkBgSecondary : ColorTokens.lightBgSecondary);

                final textStyle = FontTokens.monoCode.copyWith(
                  fontSize: 12,
                  color: isDark ? ColorTokens.darkTextPrimary : ColorTokens.lightTextPrimary,
                );

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    DataCell(
                      Text(
                        '${inst.quotaNumber}',
                        style: textStyle.copyWith(color: textMuted),
                      ),
                    ),
                    DataCell(
                      Text(
                        dateFmt.format(inst.dueDate),
                        style: textStyle.copyWith(
                          color: s == 'vencido' ? ColorTokens.statusDanger : textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyUtils.format(inst.quotaValue),
                        style: textStyle,
                      ),
                    ),
                    DataCell(
                      Text(
                        inst.paidAmount > 0 ? CurrencyUtils.format(inst.paidAmount) : '—',
                        style: textStyle.copyWith(
                          color: inst.paidAmount > 0 ? ColorTokens.statusSuccess : textMuted,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyUtils.format(row.balance),
                        style: textStyle.copyWith(
                          color: row.balance > 0 ? ColorTokens.statusDanger : ColorTokens.statusSuccess,
                        ),
                      ),
                    ),
                    DataCell(InstStatusBadge(status: s)),
                    DataCell(
                      Text(
                        inst.paymentMethod.isNotEmpty ? inst.paymentMethod : '—',
                        style: textStyle.copyWith(color: textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowData {
  final CreditInstallment inst;
  final double balance;

  _RowData({required this.inst, required this.balance});
}

