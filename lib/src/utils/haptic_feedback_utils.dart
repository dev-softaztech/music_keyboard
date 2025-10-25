import 'package:flutter/services.dart';

class HapticFeedbackUtils {
  /// Provides a gentle, short vibration to indicate popup appearance
  /// Uses Flutter's built-in haptic feedback for cross-platform support
  static Future<void> lightVibration() async {
    try {
      // Provide a light haptic feedback
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Silently handle any haptic feedback errors
      // This ensures the app continues to work even if haptic feedback fails
      print('Haptic feedback error: $e');
    }
  }
}
