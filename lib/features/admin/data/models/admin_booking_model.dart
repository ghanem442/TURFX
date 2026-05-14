class AdminBookingModel {
  final String id;
  final String? bookingCode;

  final String status;
  final String? paymentStatus;
  final String? paymentGateway;
  final String? verificationStatus;
  final String? referenceCode;
  final String? screenshotUrl;
  final String? rejectionReason;

  final String? playerId;
  final String? playerName;
  final String? playerEmail;
  final String? playerPhone;

  final String? fieldId;
  final String? fieldName;
  final String? fieldAddress;

  final String? ownerId;
  final String? ownerName;
  final String? ownerEmail;

  final DateTime? scheduledDate;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  final double? totalPrice;
  final double? depositAmount;
  final double? remainingAmount;
  final double? commissionAmount;
  final double? commissionRate;
  final double? ownerRevenue;
  final double? refundAmount;

  final bool isCheckedIn;
  final DateTime? checkedInAt;

  final bool hasQr;
  final String? qrToken;
  final bool qrUsed;
  final DateTime? qrUsedAt;

  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminBookingModel({
    required this.id,
    required this.bookingCode,
    required this.status,
    required this.paymentStatus,
    required this.paymentGateway,
    required this.verificationStatus,
    required this.referenceCode,
    required this.screenshotUrl,
    required this.rejectionReason,
    required this.playerId,
    required this.playerName,
    required this.playerEmail,
    required this.playerPhone,
    required this.fieldId,
    required this.fieldName,
    required this.fieldAddress,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.scheduledDate,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.totalPrice,
    required this.depositAmount,
    required this.remainingAmount,
    required this.commissionAmount,
    required this.commissionRate,
    required this.ownerRevenue,
    required this.refundAmount,
    required this.isCheckedIn,
    required this.checkedInAt,
    required this.hasQr,
    required this.qrToken,
    required this.qrUsed,
    required this.qrUsedAt,
    required this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusUpper => status.trim().toUpperCase();

  String get paymentStatusUpper => (paymentStatus ?? '').trim().toUpperCase();

  bool get hasManualPaymentReview =>
      statusUpper == 'PENDING_PAYMENT' ||
      verificationStatusUpper == 'PENDING' ||
      verificationStatusUpper == 'LOCKED' ||
      paymentStatusUpper == 'PENDING';

  String get verificationStatusUpper =>
      (verificationStatus ?? '').trim().toUpperCase();

  factory AdminBookingModel.fromJson(Map<String, dynamic> json) {
    final player = json['player'] is Map
        ? Map<String, dynamic>.from(json['player'] as Map)
        : <String, dynamic>{};

    final field = json['field'] is Map
        ? Map<String, dynamic>.from(json['field'] as Map)
        : <String, dynamic>{};

    final owner = json['owner'] is Map
        ? Map<String, dynamic>.from(json['owner'] as Map)
        : <String, dynamic>{};

    final payment = json['payment'] is Map
        ? Map<String, dynamic>.from(json['payment'] as Map)
        : <String, dynamic>{};

    final scheduledDate = _parseDate(
      json['scheduledDate'] ?? json['date'],
    );

    final scheduledStart = _parseDate(
          json['scheduledStartTime'] ?? json['scheduledStart'],
        ) ??
        _combineDateAndTime(
          json['scheduledDate'] ?? json['date'],
          json['startTime'],
        );

    var scheduledEnd = _parseDate(
          json['scheduledEndTime'] ?? json['scheduledEnd'],
        ) ??
        _combineDateAndTime(
          json['scheduledDate'] ?? json['date'],
          json['endTime'],
        );

    if (scheduledStart != null &&
        scheduledEnd != null &&
        !scheduledEnd.isAfter(scheduledStart)) {
      scheduledEnd = scheduledEnd.add(const Duration(days: 1));
    }

    return AdminBookingModel(
      id: (json['id'] ?? '').toString(),
      bookingCode: json['bookingCode']?.toString(),

      status: (json['status'] ?? '').toString(),

      paymentStatus: _firstNonEmpty([
        payment['status'],
        json['paymentStatus'],
      ]),
      paymentGateway: _firstNonEmpty([
        payment['gateway'],
        json['paymentGateway'],
      ]),
      verificationStatus: _firstNonEmpty([
        payment['verificationStatus'],
        json['verificationStatus'],
      ]),
      referenceCode: _firstNonEmpty([
        payment['referenceCode'],
        json['referenceCode'],
      ]),
      screenshotUrl: _firstNonEmpty([
        payment['screenshotUrl'],
        json['screenshotUrl'],
      ]),
      rejectionReason: _firstNonEmpty([
        payment['rejectionReason'],
        json['rejectionReason'],
      ]),

      playerId: _firstNonEmpty([
        player['id'],
        json['playerId'],
      ]),
      playerName: _firstNonEmpty([
        player['name'],
        json['playerName'],
      ]),
      playerEmail: _firstNonEmpty([
        player['email'],
        json['playerEmail'],
      ]),
      playerPhone: _firstNonEmpty([
        player['phone'],
        player['phoneNumber'],
        json['playerPhone'],
      ]),

      fieldId: _firstNonEmpty([
        field['id'],
        json['fieldId'],
      ]),
      fieldName: _firstNonEmpty([
        field['name'],
        field['fieldName'],
        json['fieldName'],
      ]),
      fieldAddress: _firstNonEmpty([
        field['address'],
        json['fieldAddress'],
      ]),

      ownerId: _firstNonEmpty([
        owner['id'],
        json['ownerId'],
      ]),
      ownerName: _firstNonEmpty([
        owner['name'],
        json['ownerName'],
      ]),
      ownerEmail: _firstNonEmpty([
        owner['email'],
        json['ownerEmail'],
      ]),

      scheduledDate: scheduledDate,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,

      totalPrice: _toDoubleOrNull(json['totalPrice']),
      depositAmount: _toDoubleOrNull(
        json['depositAmount'] ?? json['deposit'],
      ),
      remainingAmount: _toDoubleOrNull(json['remainingAmount']),
      commissionAmount: _toDoubleOrNull(json['commissionAmount']),
      commissionRate: _toDoubleOrNull(json['commissionRate']),
      ownerRevenue: _toDoubleOrNull(json['ownerRevenue']),
      refundAmount: _toDoubleOrNull(json['refundAmount']),

      isCheckedIn: json['isCheckedIn'] == true,
      checkedInAt: _parseDate(json['checkedInAt']),

      hasQr: json['hasQr'] == true,
      qrToken: json['qrToken']?.toString(),
      qrUsed: json['qrUsed'] == true,
      qrUsedAt: _parseDate(json['qrUsedAt']),

      cancelledAt: _parseDate(json['cancelledAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _combineDateAndTime(dynamic dateValue, dynamic timeValue) {
    final date = _parseDate(dateValue);
    if (date == null) return null;
    if (timeValue == null) return date;

    final raw = timeValue.toString().trim();
    if (raw.isEmpty) return date;

    final fullDateTime = DateTime.tryParse(raw);
    if (fullDateTime != null) return fullDateTime.toLocal();

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
}