import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bookings/presentation/providers/booking_providers.dart';
import '../../features/bookings/presentation/providers/payment_local_store_provider.dart';
import '../../features/wallet/presentation/providers/wallet_providers.dart';
import '../routing/app_router.dart';
import 'app_notification_payload.dart';

class NotificationsService {
  NotificationsService(this.ref);

  final Ref ref;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'booking_updates_channel',
    'Booking Updates',
    description: 'Notifications for payment and booking updates',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    await _initLocalNotifications();

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payloadText = response.payload;
        if (payloadText == null || payloadText.trim().isEmpty) return;

        try {
          final decoded = jsonDecode(payloadText);
          if (decoded is Map<String, dynamic>) {
            final payload = AppNotificationPayload.fromMap(decoded);
            await _handleNotificationTap(payload);
          } else if (decoded is Map) {
            final payload = AppNotificationPayload.fromMap(
              Map<String, dynamic>.from(decoded),
            );
            await _handleNotificationTap(payload);
          }
        } catch (_) {}
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _handleNotificationTap(AppNotificationPayload payload) async {
    await _refreshFromPayload(payload);
    _navigateFromPayload(payload);
  }

  Future<void> _refreshFromPayload(AppNotificationPayload payload) async {
    final bookingId = payload.bookingId;
    final paymentId = payload.paymentId;

    if (bookingId != null && bookingId.isNotEmpty) {
      ref.invalidate(bookingByIdProvider(bookingId));
      ref.invalidate(bookingQrProvider(bookingId));
    }

    if (paymentId != null && paymentId.isNotEmpty) {
      ref.invalidate(paymentVerificationStatusProvider(paymentId));
    }

    _invalidateAllBookingsQueries();

    switch (payload.type) {
      case AppNotificationType.paymentApproved:
        if (bookingId != null && bookingId.isNotEmpty) {
          ref.invalidate(bookingByIdProvider(bookingId));
          ref.invalidate(bookingQrProvider(bookingId));
          await ref.read(bookingByIdProvider(bookingId).future);
          await ref.read(paymentLocalStoreProvider).clearPaymentId(
                bookingId: bookingId,
              );
        }

        if (paymentId != null && paymentId.isNotEmpty) {
          ref.invalidate(paymentVerificationStatusProvider(paymentId));
          await ref.read(paymentVerificationStatusProvider(paymentId).future);
        }

        await ref.read(walletProvider.notifier).refreshWallet();
        break;

      case AppNotificationType.paymentRejected:
        if (paymentId != null && paymentId.isNotEmpty) {
          ref.invalidate(paymentVerificationStatusProvider(paymentId));
          await ref.read(paymentVerificationStatusProvider(paymentId).future);
        }

        if (bookingId != null && bookingId.isNotEmpty) {
          ref.invalidate(bookingByIdProvider(bookingId));
          await ref.read(bookingByIdProvider(bookingId).future);
        }
        break;

      case AppNotificationType.bookingConfirmed:
        if (bookingId != null && bookingId.isNotEmpty) {
          ref.invalidate(bookingByIdProvider(bookingId));
          ref.invalidate(bookingQrProvider(bookingId));
          await ref.read(bookingByIdProvider(bookingId).future);
        }

        await ref.read(walletProvider.notifier).refreshWallet();
        break;

      case AppNotificationType.unknown:
        break;
    }
  }

  void _invalidateAllBookingsQueries() {
    const queries = [
      MyBookingsQuery(page: 1, limit: 20),
      MyBookingsQuery(category: 'upcoming', page: 1, limit: 20),
      MyBookingsQuery(category: 'cancelled', page: 1, limit: 20),
      MyBookingsQuery(category: 'played', page: 1, limit: 20),
      MyBookingsQuery(category: 'expired', page: 1, limit: 20),
      MyBookingsQuery(status: 'CONFIRMED', page: 1, limit: 20),
      MyBookingsQuery(status: 'PENDING_PAYMENT', page: 1, limit: 20),
      MyBookingsQuery(status: 'CHECKED_IN', page: 1, limit: 20),
      MyBookingsQuery(status: 'CANCELLED_REFUNDED', page: 1, limit: 20),
      MyBookingsQuery(status: 'CANCELLED_NO_REFUND', page: 1, limit: 20),
      MyBookingsQuery(status: 'PLAYED', page: 1, limit: 20),
      MyBookingsQuery(status: 'EXPIRED_NO_SHOW', page: 1, limit: 20),
      MyBookingsQuery(status: 'PAYMENT_FAILED', page: 1, limit: 20),
    ];

    for (final query in queries) {
      ref.invalidate(myBookingsProvider(query));
    }
  }

  /// Shows a local notification — used when FCM message is received in foreground
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required AppNotificationPayload payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'booking_updates_channel',
      'Booking Updates',
      channelDescription: 'Notifications for payment and booking updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: payload.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(payload.raw),
    );
  }

  /// Shows in-app snackbar notification
  void showInAppSnack(AppNotificationPayload payload) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_snackMessage(payload)),
        action: payload.bookingId != null
            ? SnackBarAction(
                label: 'Open',
                onPressed: () {
                  _navigateFromPayload(payload);
                },
              )
            : null,
      ),
    );
  }

  void _navigateFromPayload(AppNotificationPayload payload) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (payload.type) {
      case AppNotificationType.paymentApproved:
      case AppNotificationType.bookingConfirmed:
        if (payload.bookingId != null && payload.bookingId!.isNotEmpty) {
          context.push('/booking/${payload.bookingId}/qr');
        } else {
          context.go('/my-bookings');
        }
        break;

      case AppNotificationType.paymentRejected:
        if (payload.bookingId != null && payload.bookingId!.isNotEmpty) {
          context.go('/my-bookings');
        } else {
          context.go('/my-bookings');
        }
        break;

      case AppNotificationType.unknown:
        context.go('/my-bookings');
        break;
    }
  }

  /// Returns default notification title based on payload type
  String defaultTitle(AppNotificationPayload payload) {
    switch (payload.type) {
      case AppNotificationType.paymentApproved:
        return 'Payment Approved';
      case AppNotificationType.paymentRejected:
        return 'Payment Rejected';
      case AppNotificationType.bookingConfirmed:
        return 'Booking Confirmed';
      case AppNotificationType.unknown:
        return 'Notification';
    }
  }

  /// Returns default notification body based on payload type
  String defaultBody(AppNotificationPayload payload) {
    switch (payload.type) {
      case AppNotificationType.paymentApproved:
        return 'Your payment has been approved and your booking is confirmed.';
      case AppNotificationType.paymentRejected:
        return payload.hasReason
            ? 'Your payment was rejected: ${payload.reason}'
            : 'Your payment was rejected.';
      case AppNotificationType.bookingConfirmed:
        return 'Your booking is confirmed.';
      case AppNotificationType.unknown:
        return 'You have a new update.';
    }
  }

  String _snackMessage(AppNotificationPayload payload) {
    switch (payload.type) {
      case AppNotificationType.paymentApproved:
        return 'تم قبول الدفع وتأكيد الحجز';
      case AppNotificationType.paymentRejected:
        return payload.hasReason
            ? 'تم رفض الدفع: ${payload.reason}'
            : 'تم رفض الدفع';
      case AppNotificationType.bookingConfirmed:
        return 'تم تأكيد الحجز';
      case AppNotificationType.unknown:
        return 'وصل تحديث جديد';
    }
  }
}