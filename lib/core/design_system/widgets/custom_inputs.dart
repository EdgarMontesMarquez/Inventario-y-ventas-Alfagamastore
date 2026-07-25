import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/color_tokens.dart';
import '../tokens/font_tokens.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool autofocus;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.suffixIcon,
    this.prefixIcon,
    this.formatters,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: FontTokens.bodySmall.copyWith(
            color: ColorTokens.lightTextSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          inputFormatters: formatters,
          validator: validator,
          onChanged: onChanged,
          style: FontTokens.bodyMedium.copyWith(
            color: ColorTokens.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class CustomPasswordInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const CustomPasswordInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
  });

  @override
  State<CustomPasswordInput> createState() => _CustomPasswordInputState();
}

class _CustomPasswordInputState extends State<CustomPasswordInput> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: FontTokens.bodySmall.copyWith(
            color: ColorTokens.lightTextSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          validator: widget.validator,
          style: FontTokens.bodyMedium.copyWith(
            color: ColorTokens.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ColorTokens.lightTextSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: ColorTokens.lightBrandPrimary,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class CustomMoneyInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const CustomMoneyInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: FontTokens.bodySmall.copyWith(
            color: ColorTokens.lightTextSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          validator: validator,
          onChanged: onChanged,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: FontTokens.moneyLarge.copyWith(color: ColorTokens.lightBrandPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Container(
              alignment: Alignment.center,
              width: 32,
              child: Text(
                '\$',
                style: FontTokens.moneyLarge.copyWith(color: ColorTokens.lightBrandPrimary),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 0),
          ),
        ),
      ],
    );
  }
}

class CustomPhoneInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const CustomPhoneInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: FontTokens.bodySmall.copyWith(
            color: ColorTokens.lightTextSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          validator: validator,
          onChanged: onChanged,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-\+]')),
          ],
          style: FontTokens.bodyMedium.copyWith(
            color: ColorTokens.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: ColorTokens.lightTextSecondary),
          ),
        ),
      ],
    );
  }
}


