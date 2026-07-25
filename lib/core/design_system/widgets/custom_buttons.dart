import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/font_tokens.dart';
import '../tokens/border_shadow_tokens.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isGhost;
  final bool isFullWidth;
  final IconData? icon;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isSecondary = false,
    this.isGhost = false,
    this.isFullWidth = true,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    BorderSide border;

    if (widget.isGhost) {
      bg = Colors.transparent;
      fg = ColorTokens.lightTextPrimary;
      border = BorderSide.none;
    } else if (widget.isSecondary) {
      bg = ColorTokens.lightBgSecondary;
      fg = ColorTokens.lightBrandPrimary;
      border = const BorderSide(
        color: ColorTokens.lightBorderSubtle,
        width: 1.0,
      );
    } else {
      bg = ColorTokens.lightBrandPrimary; // Electric Blue
      fg = Colors.white;
      border = BorderSide.none;
    }

    final buttonWidget = GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ElevatedButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: ColorTokens.lightBorderStrong,
            disabledForegroundColor: ColorTokens.lightTextDisabled,
            elevation: widget.isSecondary || widget.isGhost ? 0 : 2,
            shadowColor: ColorTokens.lightBrandPrimary.withAlpha(80),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BorderShadowTokens.radiusPill),
              side: border,
            ),
          ),
          child: widget.isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: FontTokens.button.copyWith(
                        color: isEnabled ? fg : ColorTokens.lightTextDisabled,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (widget.isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}


