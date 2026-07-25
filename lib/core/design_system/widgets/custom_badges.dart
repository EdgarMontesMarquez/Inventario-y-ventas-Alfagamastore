import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/font_tokens.dart';
import '../tokens/border_shadow_tokens.dart';

class StockBadge extends StatelessWidget {
  final int stock;
  final int minStock;

  const StockBadge({
    super.key,
    required this.stock,
    required this.minStock,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    final String label;
    final IconData icon;

    if (stock == 0) {
      color = ColorTokens.statusDanger;
      bg = ColorTokens.statusDangerDim;
      label = 'Sin stock';
      icon = Icons.cancel_outlined;
    } else if (stock <= minStock) {
      color = ColorTokens.statusWarning;
      bg = ColorTokens.statusWarningDim;
      label = 'Bajo';
      icon = Icons.warning_amber_outlined;
    } else {
      color = ColorTokens.statusSuccess;
      bg = ColorTokens.statusSuccessDim;
      label = 'OK';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$stock · $label',
            style: FontTokens.bodySmall.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status; // 'al_dia' | 'mora' | 'finalizado'

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    final String label;
    final IconData icon;

    switch (status) {
      case 'al_dia':
      case 'activo':
        color = ColorTokens.statusSuccess;
        bg = ColorTokens.statusSuccessDim;
        label = 'Al día';
        icon = Icons.check_circle_outline;
        break;
      case 'mora':
      case 'vencido':
        color = ColorTokens.statusDanger;
        bg = ColorTokens.statusDangerDim;
        label = 'En mora';
        icon = Icons.error_outline;
        break;
      case 'finalizado':
      case 'pagado':
        color = ColorTokens.statusInfo;
        bg = ColorTokens.statusInfoDim;
        label = 'Finalizado';
        icon = Icons.task_alt;
        break;
      default:
        color = ColorTokens.statusNeutral;
        bg = ColorTokens.statusNeutralDim;
        label = status.toUpperCase();
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: FontTokens.bodySmall.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class InstStatusBadge extends StatelessWidget {
  final String status; // 'pagado' | 'parcial' | 'vencido' | 'pendiente'

  const InstStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    final String label;

    switch (status) {
      case 'pagado':
        color = ColorTokens.statusSuccess;
        bg = ColorTokens.statusSuccessDim;
        label = 'PAGADO';
        break;
      case 'parcial':
        color = ColorTokens.statusWarning;
        bg = ColorTokens.statusWarningDim;
        label = 'PARCIAL';
        break;
      case 'vencido':
        color = ColorTokens.statusDanger;
        bg = ColorTokens.statusDangerDim;
        label = 'VENCIDO';
        break;
      case 'pendiente':
      default:
        color = ColorTokens.statusNeutral;
        bg = ColorTokens.statusNeutralDim;
        label = 'PENDIENTE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusSM),
      ),
      child: Text(
        label,
        style: FontTokens.bodySmall.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

