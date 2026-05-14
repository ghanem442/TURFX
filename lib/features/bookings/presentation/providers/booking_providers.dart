import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/network/providers.dart';
import 'package:football/features/bookings/data/booking_repository.dart';
import 'package:football/features/bookings/data/bookings_api.dart';

import '../../data/models/booking_model.dart';
import '../../data/models/bookings_list_result_model.dart';
import '../../data/models/cancel_booking_result_model.dart';
import '../../data/models/payment_result_model.dart';
import '../../data/models/time_slot_model.dart';

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return BookingsRepository(api);
});

final timeSlotsProvider =
    FutureProvider.family<List<TimeSlotModel>, TimeSlotsQuery>((ref, q) async {
  ref.keepAlive();

  final repo = ref.watch(bookingsRepositoryProvider);

  final slots = await repo.getTimeSlots(
    fieldId: q.fieldId,
    startDate: q.startDate,
    endDate: q.endDate,
  );

  return slots;
});

final createBookingProvider =
    FutureProvider.family<BookingModel, String>((ref, timeSlotId) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  final booking = await repo.createBooking(timeSlotId: timeSlotId);
  return booking;
});

final bookingByIdProvider =
    FutureProvider.family<BookingModel, String>((ref, bookingId) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.getBookingById(bookingId: bookingId);
});

final bookingQrProvider =
    FutureProvider.family<QrCodeModel, String>((ref, bookingId) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.getQrCode(bookingId: bookingId);
});

final bookingQrEligibilityProvider =
    Provider.family<BookingQrEligibility, BookingModel>((ref, booking) {
  if (booking.isConfirmed) {
    return const BookingQrEligibility(
      canShowQr: true,
      isUsed: false,
      message: 'QR is available for this confirmed booking.',
    );
  }

  if (booking.isCheckedInStatus) {
    return const BookingQrEligibility(
      canShowQr: true,
      isUsed: true,
      message: 'This booking has already been checked in.',
    );
  }

  if (booking.isPendingPayment) {
    return const BookingQrEligibility(
      canShowQr: false,
      isUsed: false,
      message:
          'QR will be available after your payment is approved and booking is confirmed.',
    );
  }

  switch (booking.statusUpper) {
    case 'PAYMENT_FAILED':
      return const BookingQrEligibility(
        canShowQr: false,
        isUsed: false,
        message:
            'This booking was not confirmed because the payment failed or was rejected.',
      );

    case 'COMPLETED':
    case 'PLAYED':
      return const BookingQrEligibility(
        canShowQr: false,
        isUsed: true,
        message: 'This booking has already been completed.',
      );

    case 'NO_SHOW':
    case 'EXPIRED_NO_SHOW':
      return const BookingQrEligibility(
        canShowQr: false,
        isUsed: true,
        message: 'This booking is no longer eligible for QR check-in.',
      );

    case 'CANCELLED':
    case 'CANCELLED_REFUNDED':
    case 'CANCELLED_NO_REFUND':
      return const BookingQrEligibility(
        canShowQr: false,
        isUsed: false,
        message: 'This booking was cancelled, so the QR is not available.',
      );

    default:
      return BookingQrEligibility(
        canShowQr: booking.canShowQr,
        isUsed: booking.qrIsUsed,
        message: booking.canShowQr
            ? 'QR is available for this booking.'
            : 'QR availability could not be determined for this booking.',
      );
  }
});

final bookingQrEligibilityByIdProvider =
    FutureProvider.family<BookingQrEligibility, String>((ref, bookingId) async {
  final booking = await ref.watch(bookingByIdProvider(bookingId).future);
  return ref.read(bookingQrEligibilityProvider(booking));
});

final manualPaymentInfoProvider =
    FutureProvider.family<ManualPaymentInfoModel, String>((ref, gateway) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.getManualPaymentInfo(gateway: gateway);
});

final initiateDepositPaymentProvider =
    FutureProvider.family<PaymentResultModel, ManualPaymentInitParams>(
  (ref, params) async {
    final repo = ref.watch(bookingsRepositoryProvider);
    return repo.initiateDepositPayment(
      bookingId: params.bookingId,
      gateway: params.gateway,
    );
  },
);

final initiateWalletPaymentProvider =
    FutureProvider.family<PaymentResultModel, ManualPaymentInitParams>(
  (ref, params) async {
    final repo = ref.watch(bookingsRepositoryProvider);
    return repo.initiateWalletPayment(
      bookingId: params.bookingId,
      gateway: params.gateway,
    );
  },
);

final uploadPaymentScreenshotProvider = FutureProvider.family<
    PaymentUploadResultModel,
    UploadPaymentScreenshotParams>((ref, params) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.uploadPaymentScreenshot(
    paymentId: params.paymentId,
    screenshotFile: params.screenshotFile,
    notes: params.notes,
    transactionId: params.transactionId,
    senderNumber: params.senderNumber,
  );
});

final paymentVerificationStatusProvider =
    FutureProvider.family<PaymentVerificationStatusModel, String>(
  (ref, paymentId) async {
    final repo = ref.watch(bookingsRepositoryProvider);
    return repo.getVerificationStatus(paymentId: paymentId);
  },
);

final cancelBookingProvider =
    FutureProvider.family<CancelBookingResultModel, CancelBookingParams>(
  (ref, p) async {
    final repo = ref.watch(bookingsRepositoryProvider);
    return repo.cancelBooking(
      bookingId: p.bookingId,
      reason: p.reason,
    );
  },
);

final myBookingsProvider =
    FutureProvider.family<BookingsListResult, MyBookingsQuery>((ref, q) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.getMyBookings(
    status: q.status,
    category: q.category,
    fieldId: q.fieldId,
    startDate: q.startDate,
    endDate: q.endDate,
    page: q.page,
    limit: q.limit,
  );
});

class ManualPaymentInitParams {
  final String bookingId;
  final String gateway;

  const ManualPaymentInitParams({
    required this.bookingId,
    required this.gateway,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManualPaymentInitParams &&
          runtimeType == other.runtimeType &&
          bookingId == other.bookingId &&
          gateway == other.gateway;

  @override
  int get hashCode => bookingId.hashCode ^ gateway.hashCode;
}

class UploadPaymentScreenshotParams {
  final String paymentId;
  final File screenshotFile;
  final String? notes;
  final String? transactionId;
  final String? senderNumber;

  const UploadPaymentScreenshotParams({
    required this.paymentId,
    required this.screenshotFile,
    this.notes,
    this.transactionId,
    this.senderNumber,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadPaymentScreenshotParams &&
          runtimeType == other.runtimeType &&
          paymentId == other.paymentId &&
          screenshotFile.path == other.screenshotFile.path &&
          (notes ?? '') == (other.notes ?? '') &&
          (transactionId ?? '') == (other.transactionId ?? '') &&
          (senderNumber ?? '') == (other.senderNumber ?? '');

  @override
  int get hashCode =>
      paymentId.hashCode ^
      screenshotFile.path.hashCode ^
      (notes ?? '').hashCode ^
      (transactionId ?? '').hashCode ^
      (senderNumber ?? '').hashCode;
}

class CancelBookingParams {
  final String bookingId;
  final String? reason;

  const CancelBookingParams({
    required this.bookingId,
    this.reason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelBookingParams &&
          runtimeType == other.runtimeType &&
          bookingId == other.bookingId &&
          (reason ?? '') == (other.reason ?? '');

  @override
  int get hashCode => bookingId.hashCode ^ (reason ?? '').hashCode;
}

class TimeSlotsQuery {
  final String fieldId;
  final DateTime startDate;
  final DateTime endDate;

  const TimeSlotsQuery({
    required this.fieldId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlotsQuery &&
          runtimeType == other.runtimeType &&
          fieldId == other.fieldId &&
          _sameDay(startDate, other.startDate) &&
          _sameDay(endDate, other.endDate);

  @override
  int get hashCode =>
      fieldId.hashCode ^ _dayHash(startDate) ^ _dayHash(endDate);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _dayHash(DateTime d) => (d.year * 10000 + d.month * 100 + d.day);
}

class MyBookingsQuery {
  final String? status;
  final String? category;
  final String? fieldId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int limit;

  const MyBookingsQuery({
    this.status,
    this.category,
    this.fieldId,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.limit = 10,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyBookingsQuery &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          category == other.category &&
          fieldId == other.fieldId &&
          page == other.page &&
          limit == other.limit &&
          _sameDay(startDate, other.startDate) &&
          _sameDay(endDate, other.endDate);

  @override
  int get hashCode =>
      (status ?? '').hashCode ^
      (category ?? '').hashCode ^
      (fieldId ?? '').hashCode ^
      page.hashCode ^
      limit.hashCode ^
      _dayHash(startDate) ^
      _dayHash(endDate);

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int _dayHash(DateTime? d) =>
      d == null ? 0 : (d.year * 10000 + d.month * 100 + d.day);
}

class BookingQrEligibility {
  final bool canShowQr;
  final bool isUsed;
  final String message;

  const BookingQrEligibility({
    required this.canShowQr,
    required this.isUsed,
    required this.message,
  });
}