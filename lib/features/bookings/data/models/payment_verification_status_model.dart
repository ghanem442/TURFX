class PaymentVerificationStatusModel {
  final String paymentId;
  final String referenceCode;
  final String verificationStatus;
  final String screenshotUrl;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime? paymentExpiresAt;
  final int uploadAttempts;
  final int maxUploadAttempts;
  final bool isFlagged;
  final String estimatedVerificationTime;

  const PaymentVerificationStatusModel({
    required this.paymentId,
    required this.referenceCode,
    required this.verificationStatus,
    required this.screenshotUrl,
    required this.submittedAt,
    required this.verifiedAt,
    required this.rejectionReason,
    required this.paymentExpiresAt,
    required this.uploadAttempts,
    required this.maxUploadAttempts,
    required this.isFlagged,
    required this.estimatedVerificationTime,
  });

  factory PaymentVerificationStatusModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    return PaymentVerificationStatusModel(
      paymentId: (json['paymentId'] ?? '').toString(),
      referenceCode: (json['referenceCode'] ?? '').toString(),
      verificationStatus: (json['verificationStatus'] ?? '').toString(),
      screenshotUrl: (json['screenshotUrl'] ?? '').toString(),
      submittedAt: parseDateTime(json['submittedAt']),
      verifiedAt: parseDateTime(json['verifiedAt']),
      rejectionReason: json['rejectionReason']?.toString(),
      paymentExpiresAt: parseDateTime(json['paymentExpiresAt']),
      uploadAttempts: toInt(json['uploadAttempts']),
      maxUploadAttempts: toInt(json['maxUploadAttempts']),
      isFlagged: json['isFlagged'] == true,
      estimatedVerificationTime:
          (json['estimatedVerificationTime'] ?? '').toString(),
    );
  }
}
