import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../../core/design_system/widgets/custom_buttons.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../shared/widgets/app_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await ref.read(authProvider.notifier).login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (error == null) {
      context.go('/dashboard');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const textMuted = ColorTokens.lightTextSecondary;
    const titleColor = ColorTokens.lightTextPrimary;

    return Scaffold(
      backgroundColor: ColorTokens.lightBgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogo(size: 150),
                  const SizedBox(height: 5),
                  
                  Text(
                    'Iniciar  Sesión',
                    style: FontTokens.h1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ALFA GAMA STORE',
                    style: FontTokens.bodySmall.copyWith(
                      color: textMuted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 36),

                  CustomTextField(
                    controller: _usernameController,
                    label: 'Correo Electrónico',
                    hint: 'usuario@alfagamastore.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20, color: textMuted),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El correo es requerido';
                      }
                      if (!val.trim().contains('@')) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  CustomPasswordInput(
                    controller: _passwordController,
                    label: 'Contraseña',
                    hint: 'Ingresa tu contraseña',
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'La contraseña es requerida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ColorTokens.statusDangerDim,
                        border: Border.all(color: ColorTokens.statusDanger.withAlpha(120), width: 1.2),
                        borderRadius: BorderRadius.circular(BorderShadowTokens.radiusMD),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline, color: ColorTokens.statusDanger, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Aviso de Inicio de Sesión',
                                  style: TextStyle(
                                    color: ColorTokens.statusDanger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: ColorTokens.statusDanger),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage!,
                            style: FontTokens.bodySmall.copyWith(
                              color: ColorTokens.lightTextPrimary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  CustomButton(
                    text: 'Iniciar Sesión',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 36),

                  Text(
                    'Alfagamastore ©2026 - Todos los derechos reservados',
                    style: FontTokens.bodySmall.copyWith(
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


