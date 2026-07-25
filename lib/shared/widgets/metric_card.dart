import 'package:flutter/material.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/tokens/border_shadow_tokens.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;
  final double? trendPercentage;
  final List<double>? sparklineData;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    this.trendPercentage,
    this.sparklineData,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = ColorTokens.lightSurfacePrimary;
    const borderCol = ColorTokens.lightBorderSubtle;
    const labelCol = ColorTokens.lightTextSecondary;
    const subCol = ColorTokens.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: BorderShadowTokens.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: FontTokens.bodySmall.copyWith(
                    color: labelCol,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trendPercentage != null) ...[
                const SizedBox(width: 4),
                _buildTrendBadge(),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: FontTokens.metric.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: FontTokens.bodySmall.copyWith(color: subCol, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sparklineData != null && sparklineData!.isNotEmpty)
                SizedBox(
                  width: 54,
                  height: 18,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      data: sparklineData!,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBadge() {
    final isPositive = trendPercentage! >= 0;
    final color = isPositive ? ColorTokens.statusSuccess : ColorTokens.statusDanger;
    final bg = isPositive ? ColorTokens.statusSuccessDim : ColorTokens.statusDangerDim;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusPill),
      ),
      child: Text(
        '$sign${trendPercentage!.toStringAsFixed(1)}%',
        style: FontTokens.bodySmall.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    
    double minVal = data[0];
    double maxVal = data[0];
    for (var val in data) {
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    
    final double valRange = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final relativeY = (data[i] - minVal) / valRange;
      final y = size.height - (relativeY * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


