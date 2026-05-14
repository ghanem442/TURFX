enum AppNotificationType {
  paymentApproved,
  paymentRejected,
  bookingConfirmed,
  unknown,
}

class AppNotificationPayload {
  final AppNotificationType type;
  final String? bookingId;
  final String? paymentId;
  final String? reason;
  final String? fieldName;
  final String? date;
  final Map<String, dynamic> raw;

  const AppNotificationPayload({
    required this.type,
    required this.bookingId,
    required this.paymentId,
    required this.reason,
    required this.fieldName,
    required this.date,
    required this.raw,
  });

  bool get hasBookingId => (bookingId ?? '').trim().isNotEmpty;
  bool get hasPaymentId => (paymentId ?? '').trim().isNotEmpty;
  bool get hasReason => (reason ?? '').trim().isNotEmpty;

  factory AppNotificationPayload.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] ?? '').toString().trim();

    return AppNotificationPayload(
      type: _parseType(rawType),
      bookingId: _nullableTrim(map['bookingId']),
      paymentId: _nullableTrim(map['paymentId']),
      reason: _nullableTrim(map['reason']),
      fieldName: _nullableTrim(map['fieldName']),
      date: _nullableTrim(map['date']),
      raw: Map<String, dynamic>.from(map),
    );
  }

  static AppNotificationType _parseType(String value) {
    switch (value) {
      case 'payment_approved':
        return AppNotificationType.paymentApproved;
      case 'payment_rejected':
        return AppNotificationType.paymentRejected;
      case 'booking_confirmed':
        return AppNotificationType.bookingConfirmed;
      default:
        return AppNotificationType.unknown;
    }
  }

  static String? _nullableTrim(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
    }
}