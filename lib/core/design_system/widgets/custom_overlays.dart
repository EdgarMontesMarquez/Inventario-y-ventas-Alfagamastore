import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/font_tokens.dart';
import '../tokens/border_shadow_tokens.dart';

class CustomOverlays {
  CustomOverlays._();

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? ColorTokens.darkSurfacePrimary : ColorTokens.lightSurfacePrimary;
    final handleColor = isDark ? ColorTokens.darkBorderStrong : ColorTokens.lightBorderStrong;
    final titleColor = isDark ? ColorTokens.darkTextPrimary : ColorTokens.lightTextPrimary;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BorderShadowTokens.radiusXL),
        ),
      ),
      barrierColor: Colors.black.withAlpha(140),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final availableHeight = mediaQuery.size.height * 0.85;

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          duration: const Duration(milliseconds: 150),
          curve: Curves.decelerate,
          child: Container(
            constraints: BoxConstraints(maxHeight: availableHeight),
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Manija para arrastrar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (title != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: FontTokens.h3.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark ? ColorTokens.darkTextSecondary : ColorTokens.lightTextSecondary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? ColorTokens.darkSurfaceSecondary : ColorTokens.lightBgTertiary,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? ColorTokens.darkSurfacePrimary : ColorTokens.lightSurfacePrimary;
    final border = isDark ? ColorTokens.darkBorderSubtle : ColorTokens.lightBorderSubtle;
    final titleColor = isDark ? ColorTokens.darkTextPrimary : ColorTokens.lightTextPrimary;
    final bodyColor = isDark ? ColorTokens.darkTextSecondary : ColorTokens.lightTextSecondary;

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (context) {
        return AlertDialog(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
            side: BorderSide(color: border),
          ),
          title: Text(
            title,
            style: FontTokens.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          content: Text(
            message,
            style: FontTokens.bodyMedium.copyWith(color: bodyColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                cancelLabel,
                style: FontTokens.bodyMedium.copyWith(color: bodyColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDestructive ? ColorTokens.statusDanger : (isDark ? ColorTokens.darkBrandPrimary : ColorTokens.lightBrandPrimary),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BorderShadowTokens.radiusMD),
                ),
                elevation: 0,
              ),
              child: Text(
                confirmLabel,
                style: FontTokens.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

