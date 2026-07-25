import 'package:flutter/material.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: ColorTokens.error,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: FontTokens.h3.copyWith(
                fontWeight: FontWeight.bold,
                color: ColorTokens.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: FontTokens.bodyMedium.copyWith(color: ColorTokens.textMuted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorTokens.surfaceElevated,
                  foregroundColor: ColorTokens.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: ColorTokens.border),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
