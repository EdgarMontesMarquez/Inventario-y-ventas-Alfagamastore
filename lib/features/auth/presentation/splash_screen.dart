import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/tokens/font_tokens.dart';
import '../../../core/design_system/tokens/border_shadow_tokens.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fullNameFadeAnimation;
  late final Animation<double> _progressAnimation;
  late final Animation<double> _messageFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _fullNameFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeInOut),
      ),
    );

    _messageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final authState = ref.read(authProvider);
          if (authState.isAuthenticated) {
            context.go('/dashboard');
          } else {
            context.go('/login');
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withAlpha(35),
            color.withAlpha(0),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.lightBgPrimary,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _buildGlow(ColorTokens.lightBrandPrimary, 320),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _buildGlow(ColorTokens.lightBrandSecondary, 240),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: ColorTokens.lightBorderSubtle, width: 1.5),
                      boxShadow: BorderShadowTokens.shadowClayCard,
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fullNameFadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Alfa Gama Store',
                        style: FontTokens.h1.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: ColorTokens.lightTextPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SISTEMA INTEGRAL ERP & POS',
                        style: FontTokens.label.copyWith(
                          color: ColorTokens.lightBrandPrimary,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ColorTokens.lightBgSecondary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  ColorTokens.lightBrandPrimary,
                                  ColorTokens.lightBrandSecondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorTokens.lightBrandPrimary.withAlpha(80),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _messageFadeAnimation,
                  child: Text(
                    'Moda, Calidad y Estilo',
                    textAlign: TextAlign.center,
                    style: FontTokens.bodyMedium.copyWith(
                      fontSize: 14,
                      color: ColorTokens.lightTextSecondary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

