class PaymentUploadResultModel {
  final String paymentId;
  final String screenshotUrl;
  final String verificationStatus;
  final int uploadAttempts;
  final int maxUploadAttempts;
  final Map<String, dynamic> message;

  const PaymentUploadResultModel({
    required this.paymentId,
    required this.screenshotUrl,
    required this.verificationStatus,
    required this.uploadAttempts,
    required this.maxUploadAttempts,
    required this.message,
  });

  String get messageAr => (message['ar'] ?? '').toString();
  String get messageEn => (message['en'] ?? '').toString();

  factory PaymentUploadResultModel.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    return PaymentUploadResultModel(
      paymentId: (json['paymentId'] ?? '').toString(),
      screenshotUrl: (json['screenshotUrl'] ?? '').toString(),
      verificationStatus: (json['verificationStatus'] ?? '').toString(),
      uploadAttempts: toInt(json['uploadAttempts']),
      maxUploadAttempts: toInt(json['maxUploadAttempts']),
      message: json['message'] is Map
          ? Map<String, dynamic>.from(json['message'] as Map)
          : const {},
    );
  }
}
