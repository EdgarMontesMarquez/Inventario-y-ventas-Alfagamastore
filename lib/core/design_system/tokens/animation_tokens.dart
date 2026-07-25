import 'package:flutter/animation.dart';

/// Alfa Design Language 2.0 - Animation Tokens
/// Duraciones en milisegundos y curvas mecánicas precisas.
class AnimationTokens {
  AnimationTokens._();

  // Duraciones
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // Curvas Mecánicas
  static const Curve curveDefault = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;
  static const Curve curveSlideUp = Cubic(0.2, 0.8, 0.2, 1.0);
}

