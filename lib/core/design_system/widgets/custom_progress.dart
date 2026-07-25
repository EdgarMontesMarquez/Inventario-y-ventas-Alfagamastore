import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';

class ProgressBar extends StatelessWidget {
  final double percentage; // 0.0 to 100.0
  final Color color;
  final double height;

  const ProgressBar({
    super.key,
    required this.percentage,
    this.color = ColorTokens.primary,
    this.height = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = (percentage / 100.0).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final filledWidth = totalWidth * fraction;

        return Container(
          width: totalWidth,
          height: height,
          decoration: BoxDecoration(
            color: ColorTokens.surfaceElevated,
            borderRadius: BorderRadius.circular(height),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: filledWidth,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LoadingSpinner extends StatelessWidget {
  final String? message;

  const LoadingSpinner({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ColorTokens.primary),
            strokeWidth: 3.0,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
