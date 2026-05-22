import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared navigation helpers to avoid `GoError: There is nothing to pop` and
/// keep fallbacks consistent across the app.
extension AppNavigation on BuildContext {
  void safePop({String fallback = '/home'}) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }

  void goHome() => go('/home');

  void goMyBookings() => go('/my-bookings');

  void openBookingConfirmation(Map<String, dynamic> extra) {
    push('/booking-confirmation', extra: extra);
  }
}
