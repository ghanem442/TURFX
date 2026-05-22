import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SnackBarType { success, error, info, warning }

/// Show a styled sporty snackbar
void showSportySnackBar(
  BuildContext context, {
  required String message,
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  IconData icon;
  Color iconColor;

  switch (type) {
    case SnackBarType.success:
      icon = Icons.check_circle;
      iconColor = AppColors.green;
      break;
    case SnackBarType.error:
      icon = Icons.error;
      iconColor = Colors.red;
      break;
    case SnackBarType.warning:
      icon = Icons.warning;
      iconColor = AppColors.orange;
      break;
    case SnackBarType.info:
      icon = Icons.info;
      iconColor = Colors.blue;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.darkCard : const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      duration: duration,
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDark ? AppColors.darkText : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
