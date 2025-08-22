import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color red = Color.fromARGB(255, 211, 25, 25);
  static const Color primary = primaryOrange; // or primaryBlue

  // Primary Theme Colors
  static const Color primaryOrange = Color(0xFFFD6303);
  static const Color primaryBlue = Color(0xFF021A5A);

  // Aliases for convenience
  static const Color orange = primaryOrange;
  static const Color blue = primaryBlue;
  static const Color green = Color(0xFF4CAF50);

  // AppBar Color
  static const Color appBar = primaryBlue;

  // Accent Colors
  static const Color accentOrangeLight = Color(0xFFFF8C42);
  static const Color accentBlueLight = Color(0xFF123C8C);

  // Gradients
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [primaryOrange, accentOrangeLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [primaryBlue, accentBlueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Input Fields
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color inputBorder = Color(0xFFCCCCCC);
  static const Color inputLabel =
      Color(0xFF9E9E9E); // New: Added a color for labels

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3); // New: Added an info color

  // Misc
  static const Color purpleAccent = Color(0xFF7C4DFF);
  static const Color iconColor =
      Color(0xFF757575); // New: A default color for icons

  // New: Added more gray shades for general use
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
  ];
}
