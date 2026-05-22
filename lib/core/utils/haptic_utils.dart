import 'package:flutter/services.dart';

/// Utility class for haptic feedback throughout the app
class HapticUtils {
  /// Light impact - for selections, toggles, switches
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for button presses, confirmations
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions, success states
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection click - for picker selections
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate - for errors, warnings, critical alerts
  static void error() {
    HapticFeedback.vibrate();
  }
}
