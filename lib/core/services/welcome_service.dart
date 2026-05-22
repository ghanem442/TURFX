import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/welcome_animation.dart';

/// Service to manage welcome animation display
class WelcomeService {
  static const String _lastWelcomeKey = 'last_welcome_shown';
  static const Duration _welcomeCooldown = Duration(hours: 24);

  /// Check if welcome animation should be shown
  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString(_lastWelcomeKey);

    if (lastShown == null) {
      return true; // First time
    }

    final lastShownDate = DateTime.parse(lastShown);
    final now = DateTime.now();
    final difference = now.difference(lastShownDate);

    return difference > _welcomeCooldown;
  }

  /// Mark welcome as shown
  static Future<void> markWelcomeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastWelcomeKey, DateTime.now().toIso8601String());
  }

  /// Show welcome animation overlay
  static Future<void> showWelcomeAnimation(
    BuildContext context, {
    required String userName,
    required String userRole,
  }) async {
    final shouldShow = await shouldShowWelcome();

    if (!shouldShow || !context.mounted) {
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => WelcomeAnimation(
        userName: userName,
        userRole: userRole,
        onComplete: () {
          Navigator.of(context).pop();
        },
      ),
    );

    await markWelcomeShown();
  }

  /// Force show welcome animation (for testing or special occasions)
  static Future<void> forceShowWelcome(
    BuildContext context, {
    required String userName,
    required String userRole,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => WelcomeAnimation(
        userName: userName,
        userRole: userRole,
        onComplete: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Reset welcome cooldown (for testing)
  static Future<void> resetWelcomeCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastWelcomeKey);
  }
}
