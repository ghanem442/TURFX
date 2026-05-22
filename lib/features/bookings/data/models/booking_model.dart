import 'package:football/core/network/media_url.dart';

class BookingModel {
  final String id;
  final String bookingNumber;

  final String timeSlotId;
  final String playerId;
  final String fieldId;

  final String status;

  final String? fieldName;
  final String? fieldNameAr;
  final String? fieldAddress;

  final String? playerName;
  final String? email;
  final String? phone;

  final String totalPrice;
  final String depositAmount;
  final String remainingAmount;
  final String? refundAmount;

  final String commissionAmount;
  final String commissionRate;
  final String ownerRevenue;

  final String? paymentStatus;
  final String? paymentGateway;

  final DateTime scheduledDate;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  final bool isCheckedIn;
  final DateTime? checkedInAt;
  final bool hasQr;
  final String? qrToken;
  final String? qrImageUrl;
  final bool qrIsUsed;

  final DateTime? paymentDeadline;
  final DateTime? cancellationDeadline;
  final DateTime? cancelledAt;

  final bool canCancelFromApi;
  final bool willGetRefund;
  final double? hoursUntilBooking;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingModel({
    required this.id,
    required this.bookingNumber,
    required this.timeSlotId,
    required this.playerId,
    required this.fieldId,
    required this.status,
    this.fieldName,
    this.fieldNameAr,
    this.fieldAddress,
    this.playerName,
    this.email,
    this.phone,
    required this.totalPrice,
    required this.depositAmount,
    required this.remainingAmount,
    required this.refundAmount,
    required this.commissionAmount,
    required this.commissionRate,
    required this.ownerRevenue,
    this.paymentStatus,
    this.paymentGateway,
    required this.scheduledDate,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.isCheckedIn,
    required this.checkedInAt,
    required this.hasQr,
    required this.qrToken,
    required this.qrImageUrl,
    required this.qrIsUsed,
    required this.paymentDeadline,
    required this.cancellationDeadline,
    required this.cancelledAt,
    required this.canCancelFromApi,
    required this.willGetRefund,
    required this.hoursUntilBooking,
    required this.createdAt,
    required this.updatedAt,
  });

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static double? _asNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime _epochLocal() {
    return DateTime.fromMillisecondsSinceEpoch(0).toLocal();
  }

  static DateTime _asDateTime(dynamic v) {
    if (v == null) return _epochLocal();
    if (v is DateTime) return v.toLocal();

    final parsed = DateTime.tryParse(v.toString());
    if (parsed != null) return parsed.toLocal();

    return _epochLocal();
  }

  static DateTime? _asNullableDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();

    final parsed = DateTime.tryParse(v.toString());
    return parsed?.toLocal();
  }

  static DateTime _combineDateAndTime(dynamic dateValue, dynamic timeValue) {
    final date = _asDateTime(dateValue);

    if (timeValue == null) return date;
    if (timeValue is DateTime) return timeValue.toLocal();

    final raw = timeValue.toString().trim();
    if (raw.isEmpty) return date;

    final parsedFullDateTime = DateTime.tryParse(raw);
    if (parsedFullDateTime != null) {
      final local = parsedFullDateTime.toLocal();
      return DateTime(
        date.year,
        date.month,
        date.day,
        local.hour,
        local.minute,
        local.second,
      );
    }

    final normalized = raw.replaceAll('.', ':');
    final parts = normalized.split(':');

    if (parts.length < 2) return date;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
    ).toLocal();
  }

  double get totalAsDouble => _asDouble(totalPrice);
  double get depositAsDouble => _asDouble(depositAmount);
  double get remainingAmountAsDouble => _asDouble(remainingAmount);
  double get refundAsDouble => _asDouble(refundAmount);

  double get remainingAsDouble {
    final parsedRemaining = remainingAmount.trim().isEmpty
        ? (totalAsDouble - depositAsDouble)
        : remainingAmountAsDouble;
    return parsedRemaining < 0 ? 0 : parsedRemaining;
  }

  String get statusUpper => status.trim().toUpperCase();

  String get bookingNumberDisplay {
    final x = bookingNumber.trim();
    if (x.isNotEmpty) return x;

    final rawId = id.trim();
    if (rawId.isEmpty) return 'Booking —';
    if (rawId.length <= 8) return 'Booking #$rawId';
    return 'Booking #${rawId.substring(0, 8)}';
  }

  String get fieldDisplayName {
    final ar = (fieldNameAr ?? '').trim();
    if (ar.isNotEmpty) return ar;

    final en = (fieldName ?? '').trim();
    if (en.isNotEmpty) return en;

    return '—';
  }

  bool get isConfirmed => statusUpper == 'CONFIRMED';

  bool get isPendingPayment => statusUpper == 'PENDING_PAYMENT';

  bool get isCheckedInStatus => statusUpper == 'CHECKED_IN' || isCheckedIn;

  bool get isCancelled =>
      statusUpper == 'CANCELLED' ||
      statusUpper == 'CANCELLED_REFUNDED' ||
      statusUpper == 'CANCELLED_NO_REFUND';

  bool get isPlayed =>
      statusUpper == 'PLAYED' || statusUpper == 'COMPLETED';

  bool get isExpired =>
      statusUpper == 'EXPIRED' ||
      statusUpper == 'EXPIRED_NO_SHOW' ||
      statusUpper == 'NO_SHOW' ||
      statusUpper == 'PAYMENT_FAILED';

  bool get isUpcoming =>
      isConfirmed || isPendingPayment || isCheckedInStatus;

  /// True when the API (or nested `qr`) indicates a QR exists or can be fetched.
  bool get hasQrPayload {
    if (hasQr) return true;
    if ((qrToken ?? '').trim().isNotEmpty) return true;
    if ((qrImageUrl ?? '').trim().isNotEmpty) return true;
    return false;
  }

  /// Player may open the QR screen after payment is confirmed (no narrow time window).
  bool get canShowQr {
    if (statusUpper != 'CONFIRMED' && statusUpper != 'CHECKED_IN') {
      return false;
    }
    if (isCancelled || isExpired) return false;
    return true;
  }

  /// Owner check-in window: within 60 minutes before start until 120 minutes after.
  bool get isWithinQrCheckInWindow {
    final now = DateTime.now();
    final diff = scheduledStart.difference(now).inMinutes;
    return diff <= 60 && diff >= -120;
  }

  bool get canCancel => canCancelFromApi;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final fieldObj = json['field'];
    String? parsedFieldName;
    String? parsedFieldNameAr;
    String? parsedFieldAddress;

    if (fieldObj is Map) {
      parsedFieldName = fieldObj['name']?.toString();
      parsedFieldNameAr = fieldObj['nameAr']?.toString();
      parsedFieldAddress = fieldObj['address']?.toString();
    } else {
      parsedFieldName = json['fieldName']?.toString();
      parsedFieldNameAr = json['fieldNameAr']?.toString();
      parsedFieldAddress = json['fieldAddress']?.toString();
    }

    final playerObj = json['player'];
    String? parsedPlayerName;
    String? parsedEmail;
    String? parsedPhone;

    if (playerObj is Map) {
      parsedPlayerName = playerObj['name']?.toString();
      parsedEmail = playerObj['email']?.toString();
      parsedPhone = playerObj['phone']?.toString();
    } else {
      parsedPlayerName = json['playerName']?.toString();
      parsedEmail = json['email']?.toString();
      parsedPhone = json['phone']?.toString();
    }

    final paymentObj = json['payment'];
    String? parsedPaymentStatus;
    String? parsedPaymentGateway;

    if (paymentObj is Map) {
      parsedPaymentStatus = paymentObj['status']?.toString();
      parsedPaymentGateway = paymentObj['gateway']?.toString();
    } else {
      parsedPaymentStatus = json['paymentStatus']?.toString();
      parsedPaymentGateway = json['paymentGateway']?.toString();
    }

    final qrObj = json['qr'];
    String? parsedQrToken;
    String? parsedQrImageUrl;
    bool parsedQrIsUsed = false;

    if (qrObj is Map) {
      parsedQrToken =
          qrObj['token']?.toString() ?? qrObj['qrToken']?.toString();
      parsedQrImageUrl =
          qrObj['imageUrl']?.toString() ?? qrObj['url']?.toString();
      parsedQrIsUsed = qrObj['isUsed'] == true;
    }

    final parsedStatus = (json['status'] ?? '').toString().trim().toUpperCase();

    final scheduledDate = _asDateTime(json['scheduledDate']);
    final scheduledStart = _combineDateAndTime(
      json['scheduledDate'],
      json['scheduledStartTime'] ?? json['scheduledStart'],
    );

    var scheduledEnd = _combineDateAndTime(
      json['scheduledDate'],
      json['scheduledEndTime'] ?? json['scheduledEnd'],
    );

    if (!scheduledEnd.isAfter(scheduledStart)) {
      scheduledEnd = scheduledEnd.add(const Duration(days: 1));
    }

    return BookingModel(
      id: (json['id'] ?? '').toString(),
      bookingNumber:
          (json['bookingNumber'] ?? json['booking_number'] ?? json['code'] ?? '')
              .toString(),
      timeSlotId: (json['timeSlotId'] ?? '').toString(),
      playerId: (json['playerId'] ?? '').toString(),
      fieldId: (json['fieldId'] ?? '').toString(),
      status: parsedStatus,
      fieldName: parsedFieldName,
      fieldNameAr: parsedFieldNameAr,
      fieldAddress: parsedFieldAddress,
      playerName: parsedPlayerName,
      email: parsedEmail,
      phone: parsedPhone,
      totalPrice: (json['totalPrice'] ?? '0').toString(),
      depositAmount: (json['depositAmount'] ?? '0').toString(),
      remainingAmount: (json['remainingAmount'] ?? '0').toString(),
      refundAmount: json['refundAmount']?.toString(),
      commissionAmount: (json['commissionAmount'] ?? '0').toString(),
      commissionRate: (json['commissionRate'] ?? '0').toString(),
      ownerRevenue: (json['ownerRevenue'] ?? '0').toString(),
      paymentStatus: parsedPaymentStatus,
      paymentGateway: parsedPaymentGateway,
      scheduledDate: scheduledDate,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      isCheckedIn: (json['isCheckedIn'] ?? false) == true ||
          parsedStatus == 'CHECKED_IN',
      checkedInAt: _asNullableDateTime(json['checkedInAt']),
      hasQr: (json['hasQr'] ?? false) == true ||
          (parsedQrToken?.trim().isNotEmpty ?? false) ||
          (parsedQrImageUrl?.trim().isNotEmpty ?? false),
      qrToken: parsedQrToken ?? json['qrToken']?.toString(),
      qrImageUrl: resolvePublicMediaUrl(
        parsedQrImageUrl ?? json['qrImageUrl']?.toString() ?? '',
      ),
      qrIsUsed: parsedQrIsUsed || (json['qrIsUsed'] ?? false) == true,
      paymentDeadline: _asNullableDateTime(json['paymentDeadline']),
      cancellationDeadline: _asNullableDateTime(json['cancellationDeadline']),
      cancelledAt: _asNullableDateTime(json['cancelledAt']),
      canCancelFromApi: (json['canCancel'] ?? false) == true,
      willGetRefund: (json['willGetRefund'] ?? false) == true,
      hoursUntilBooking: _asNullableDouble(json['hoursUntilBooking']),
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }
}

class QrCodeModel {
  final String qrToken;
  final String imageUrl;
  final bool isUsed;
  final DateTime? usedAt;

  const QrCodeModel({
    required this.qrToken,
    required this.imageUrl,
    required this.isUsed,
    required this.usedAt,
  });

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(
      qrToken: (json['qrToken'] ?? json['token'] ?? '').toString(),
      imageUrl: resolvePublicMediaUrl(
        (json['imageUrl'] ?? json['url'] ?? '').toString(),
      ),
      isUsed: (json['isUsed'] ?? false) == true,
      usedAt: json['usedAt'] == null
          ? null
          : DateTime.tryParse(json['usedAt'].toString())?.toLocal(),
    );
  }
}