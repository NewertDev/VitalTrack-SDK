import 'package:flutter/material.dart';

class AppColors {
  // Main Color
  static const Color primary = Color(0xFF24306B);
  static const Color point = Color(0xFF24306B);
  static const Color primaryDark = Color(0xFF05263A);

  static const Color grey = Color(0xFF707070);
  static const Color greyLight = Color(0xFFe8e8e8);
  static const Color bodyColor = Color(0xFF333333);
  static const Color appBackgroundColor = Color(0xFFF3F3F3);
}

class AppTextStyle {
  // Colored text for merge()
  static const TextStyle primaryColoredText =
      TextStyle(color: AppColors.primary);

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontSize: 60,
    fontWeight: FontWeight.w100,
  );

  // Title
  static const TextStyle titleLarge = TextStyle(
      fontSize: 60,
      fontWeight: FontWeight.w600,
      color: AppColors.bodyColor,
      height: 1.2);
  static const TextStyle supportTitleLarge =
      TextStyle(fontSize: 50, color: AppColors.bodyColor, height: 1.2);
  static const TextStyle titleMedium = TextStyle(
    fontSize: 35,
    fontWeight: FontWeight.w600,
    color: AppColors.bodyColor,
  );

  static const TextStyle supportTitleMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.bodyColor,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.bodyColor,
  );

  // Subtitle
  static const TextStyle subtitleLarge =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white);
  static const TextStyle subtitleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );
  static const TextStyle subtitleSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: Colors.white,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 25,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 18,
  );
  static const TextStyle bodyRegular = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.6,
  );
  static const TextStyle bodySmallHyperlink = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static const TextStyle bodyRegularHyperlink = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
  );

  static const TextStyle buttonRegular = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  // Header
  static const TextStyle headerButtonText = TextStyle(
    fontSize: 17,
  );
}

class AppFilledButtonColor extends MaterialStateColor {
  const AppFilledButtonColor() : super(_defaultColor);

  static const int _defaultColor = 0xFF24306B;
  static const int _pressedColor = 0xFF001B9B;

  @override
  Color resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.pressed)) {
      return const Color(_pressedColor);
    }
    return const Color(_defaultColor);
  }
}

class AppButtonElevation extends MaterialStateProperty<double> {
  @override
  resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.pressed)) {
      return 1.0;
    }
    return 4;
  }
}
