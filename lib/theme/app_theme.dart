import 'package:flutter/material.dart';

/// WeChat-inspired palette. Friendly, light, familiar.
abstract final class AppColors {
  /// WeChat brand green — used for accents, the send button, active tabs.
  static const brand = Color(0xFF07C160);

  /// Outgoing chat bubble green.
  static const bubbleOut = Color(0xFF95EC69);

  /// Incoming chat bubble (and cards).
  static const bubbleIn = Color(0xFFFFFFFF);

  /// App canvas — the soft WeChat gray.
  static const canvas = Color(0xFFEDEDED);

  /// Nav bars (top + bottom).
  static const bar = Color(0xFFF7F7F7);

  static const textPrimary = Color(0xFF181818);
  static const textSecondary = Color(0xFF8A8A8A);
  static const divider = Color(0xFFDADADA);

  /// Inactive bottom-tab tint.
  static const tabIdle = Color(0xFF9A9A9A);

  /// Unread badge.
  static const badge = Color(0xFFFA5151);

  static const error = Color(0xFFFA5151);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: '.SF Pro Text',
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      brightness: Brightness.light,
    ),
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
