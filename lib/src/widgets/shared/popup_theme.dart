import 'package:flutter/material.dart';

/// Shared styling constants for all popup dialogs in the app
/// Provides consistent black and white theme across all popups
class PopupTheme {
  // Color palette
  static const Color primaryBackground = Colors.white;
  static const Color headerBackground = Color(0xFFF5F5F5);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0xFF666666);
  static const Color accent = Colors.black;
  static const Color shadowColor = Colors.black12;

  // Layout constants
  static const double borderRadius = 12.0;
  static const double standardPadding = 16.0;
  static const double dialogMargin = 20.0;
  static const double headerPadding = 16.0;
  static const double contentPadding = 20.0;
  static const double actionsPadding = 16.0;

  // Typography
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  // Shadow
  static const List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: shadowColor,
      spreadRadius: 2,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  // Dialog decoration
  static BoxDecoration get dialogDecoration => BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: dialogShadow,
      );

  // Header decoration
  static BoxDecoration get headerDecoration => BoxDecoration(
        color: headerBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
        ),
        border: const Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      );

  // Primary button style
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: primaryBackground,
        textStyle: buttonStyle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      );

  // Secondary button style
  static ButtonStyle get secondaryButtonStyle => TextButton.styleFrom(
        foregroundColor: textSecondary,
        textStyle: buttonStyle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      );

  // Grid item decoration
  static BoxDecoration get gridItemDecoration => BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: shadowColor,
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      );

  // Input field decoration
  static InputDecoration get inputDecoration => InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      );

  // Tab bar theme
  static TabBarTheme get tabBarTheme => const TabBarTheme(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.tab,
      );

  // Slider theme
  static SliderThemeData get sliderTheme => SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: borderColor,
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.1),
        valueIndicatorColor: accent,
        valueIndicatorTextStyle: const TextStyle(
          color: primaryBackground,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );

  /// Creates a standardized popup header with title and close button
  static Widget buildHeader({
    required String title,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(headerPadding),
      decoration: headerDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: titleStyle),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Creates standardized action buttons row
  static Widget buildActions({
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    String cancelText = 'Cancel',
    String confirmText = 'Save',
  }) {
    return Padding(
      padding: const EdgeInsets.all(actionsPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancel,
            style: secondaryButtonStyle,
            child: Text(cancelText),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onConfirm,
            style: primaryButtonStyle,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
