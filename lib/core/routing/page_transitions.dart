import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AppTransitionStyle {
  /// Default push: fade + subtle horizontal slide.
  push,

  /// Full-screen flows opened from shell tabs.
  modal,

  /// Fast fade for auth / splash.
  fade,
}

CustomTransitionPage<void> buildAppPage({
  required LocalKey key,
  required Widget child,
  AppTransitionStyle style = AppTransitionStyle.push,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: _durationFor(style),
    reverseTransitionDuration: _durationFor(style),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      switch (style) {
        case AppTransitionStyle.modal:
          final offsetTween = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: offsetTween.animate(curved),
              child: child,
            ),
          );
        case AppTransitionStyle.fade:
          return FadeTransition(opacity: curved, child: child);
        case AppTransitionStyle.push:
          // Bold slide-in from right (Nike/ESPN style)
          final offsetTween = Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          );
          return SlideTransition(
            position: offsetTween.animate(curved),
            child: child,
          );
      }
    },
  );
}

Duration _durationFor(AppTransitionStyle style) {
  switch (style) {
    case AppTransitionStyle.fade:
      return const Duration(milliseconds: 220);
    case AppTransitionStyle.modal:
      return const Duration(milliseconds: 320);
    case AppTransitionStyle.push:
      return const Duration(milliseconds: 280);
  }
}
