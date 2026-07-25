import 'package:flutter/material.dart';
import '../../core/design_system/tokens/color_tokens.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size = 40,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? ColorTokens.darkBrandPrimary : ColorTokens.lightBrandPrimary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                'α',
                style: TextStyle(
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

