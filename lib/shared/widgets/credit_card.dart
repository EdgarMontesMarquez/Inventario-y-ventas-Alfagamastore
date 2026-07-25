import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/credit.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../core/design_system/widgets/custom_badges.dart';
import '../../core/design_system/widgets/custom_progress.dart';
import '../../core/utils/currency_formatter.dart';

class CreditCard extends StatelessWidget {
  final Credit credit;
  final VoidCallback onTap;

  const CreditCard({
    super.key,
    required this.credit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = ColorTokens.lightSurfacePrimary;
    const borderCol = ColorTokens.lightBorderSubtle;
    const titleCol = ColorTokens.lightTextPrimary;
    const subCol = ColorTokens.lightTextSecondary;

    final df = DateFormat('dd MMM', 'es_CO');
    
    final st = credit.status;
    final pct = credit.progressPercentage;
    final od = credit.overdueQuotasCount;
    final next = credit.nextDueInstallment;

    final Color progressColor;
    if (st == 'mora') {
      progressColor = ColorTokens.statusDanger;
    } else if (st == 'finalizado') {
      progressColor = ColorTokens.statusInfo;
    } else {
      progressColor = ColorTokens.statusSuccess;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
        border: Border.all(
          color: st == 'mora' ? ColorTokens.statusDanger : borderCol,
          width: 1.0,
        ),
        boxShadow: BorderShadowTokens.shadowLevel1,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                          credit.clientName,
                          style: FontTokens.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: titleCol,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          credit.products,
                          style: FontTokens.bodySmall.copyWith(
                            color: subCol,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          credit.clientPhone,
                          style: FontTokens.monoCode.copyWith(
                            color: ColorTokens.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyUtils.format(credit.pendingBalance),
                        style: FontTokens.moneyMedium.copyWith(
                          color: ColorTokens.statusDanger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: st),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),
              ProgressBar(
                percentage: pct,
                color: progressColor,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${pct.toStringAsFixed(1)}% pagado',
                    style: FontTokens.bodySmall.copyWith(fontSize: 12, color: subCol, fontWeight: FontWeight.bold),
                  ),
                  if (od > 0)
                    Text(
                      '$od cuota${od != 1 ? 's' : ''} vencida${od != 1 ? 's' : ''}',
                      style: FontTokens.bodySmall.copyWith(
                        color: ColorTokens.statusDanger,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (next != null && st != 'finalizado')
                    Text(
                      'Próximo: ${df.format(next.dueDate)}',
                      style: FontTokens.bodySmall.copyWith(fontSize: 12, color: subCol, fontWeight: FontWeight.bold),
                    )
                  else if (st == 'finalizado')
                    Text(
                      'Finalizado',
                      style: FontTokens.bodySmall.copyWith(
                        color: ColorTokens.statusInfo,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


