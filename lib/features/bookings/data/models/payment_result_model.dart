class PaymentResultModel {
  final bool success;
  final PaymentDataModel? data;
  final PaymentErrorModel? error;
  final String? message;
  final String? status;
  final Map<String, dynamic>? raw;

  const PaymentResultModel({
    required this.success,
    required this.data,
    required this.error,
    this.message,
    this.status,
    this.raw,
  });

  bool get isSuccess => success && data != null;

  String? get errorCode {
    final code = error?.code.trim() ?? '';
    return code.isEmpty ? null : code;
  }

  String get errorEn => error?.en ?? '';
  String get errorAr => error?.ar ?? '';

  String get rootMessage => (message ?? '').trim();
  String get rootStatus => (status ?? '').trim();

  String get userMessageAr {
    if (errorAr.trim().isNotEmpty) return errorAr.trim();
    if (errorEn.trim().isNotEmpty) return errorEn.trim();
    if (rootMessage.isNotEmpty) return rootMessage;
    if (errorCode?.isNotEmpty == true) return errorCode!;
    if (rootStatus.isNotEmpty) return rootStatus;
    return 'حدث خطأ أثناء إنشاء عملية الدفع';
  }

  String get userMessageEn {
    if (errorEn.trim().isNotEmpty) return errorEn.trim();
    if (errorAr.trim().isNotEmpty) return errorAr.trim();
    if (rootMessage.isNotEmpty) return rootMessage;
    if (errorCode?.isNotEmpty == true) return errorCode!;
    if (rootStatus.isNotEmpty) return rootStatus;
    return 'Failed to initiate payment';
  }

  String get paymentId => data?.paymentId ?? '';
  String get bookingId => data?.bookingId ?? '';
  String get amount => data?.amount ?? '';
  String get currency => data?.currency ?? '';
  String get gateway => data?.gateway ?? '';
  String get normalizedGateway => gateway.trim().toUpperCase();
  String get paymentType => data?.paymentType ?? '';
  String get normalizedPaymentType => paymentType.trim().toUpperCase();
  String get referenceCode => data?.referenceCode ?? '';
  DateTime? get paymentExpiresAt => data?.paymentExpiresAt;
  int get expiryMinutes => data?.expiryMinutes ?? 0;

  Map<String, dynamic> get instructions => data?.instructions ?? const {};
  Map<String, dynamic> get accountDetails => data?.accountDetails ?? const {};
  Map<String, dynamic> get nextStep => data?.nextStep ?? const {};

  String get instructionsAr => (instructions['ar'] ?? '').toString().trim();
  String get instructionsEn => (instructions['en'] ?? '').toString().trim();

  String get nextStepAr => (nextStep['ar'] ?? '').toString().trim();
  String get nextStepEn => (nextStep['en'] ?? '').toString().trim();

  bool get hasAccountDetails => accountDetails.isNotEmpty;
  bool get hasInstructions => instructionsAr.isNotEmpty || instructionsEn.isNotEmpty;
  bool get hasNextStep => nextStepAr.isNotEmpty || nextStepEn.isNotEmpty;
  bool get hasExpiry => paymentExpiresAt != null || expiryMinutes > 0;

  bool get isVodafoneCash => normalizedGateway == 'VODAFONE_CASH';
  bool get isInstaPay => normalizedGateway == 'INSTAPAY';

  factory PaymentResultModel.fromAny(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return PaymentResultModel.fromJson(raw);
    }

    if (raw is Map) {
      return PaymentResultModel.fromJson(Map<String, dynamic>.from(raw));
    }

    return const PaymentResultModel(
      success: false,
      data: null,
      error: null,
      message: null,
      status: null,
      raw: null,
    );
  }

  factory PaymentResultModel.fromJson(Map<String, dynamic> json) {
    final root = Map<String, dynamic>.from(json);

    final rawData = root['data'];
    final dataMap = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : null);

    final rawError = root['error'];

    return PaymentResultModel(
      success: root['success'] == true,
      data: dataMap != null ? PaymentDataModel.fromJson(dataMap) : null,
      error: rawError is Map
          ? PaymentErrorModel.fromJson(Map<String, dynamic>.from(rawError))
          : null,
      message: root['message']?.toString(),
      status: root['status']?.toString(),
      raw: root,
    );
  }

  @override
  String toString() {
    return 'PaymentResultModel('
        'success: $success, '
        'paymentId: ${data?.paymentId}, '
        'bookingId: ${data?.bookingId}, '
        'gateway: ${data?.gateway}, '
        'paymentType: ${data?.paymentType}, '
        'amount: ${data?.amount}, '
        'currency: ${data?.currency}, '
        'referenceCode: ${data?.referenceCode}, '
        'paymentExpiresAt: ${data?.paymentExpiresAt}, '
        'expiryMinutes: ${data?.expiryMinutes}, '
        'message: $message, '
        'status: $status, '
        'errorCode: ${error?.code}'
        ')';
  }
}

class PaymentDataModel {
  final String paymentId;
  final String bookingId;
  final String amount;
  final String currency;
  final String gateway;
  final String paymentType;
  final String referenceCode;
  final DateTime? paymentExpiresAt;
  final int expiryMinutes;
  final Map<String, dynamic> instructions;
  final Map<String, dynamic> accountDetails;
  final Map<String, dynamic> nextStep;

  const PaymentDataModel({
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.gateway,
    required this.paymentType,
    required this.referenceCode,
    required this.paymentExpiresAt,
    required this.expiryMinutes,
    required this.instructions,
    required this.accountDetails,
    required this.nextStep,
  });

  factory PaymentDataModel.fromJson(Map<String, dynamic> json) {
    return PaymentDataModel(
      paymentId: (json['paymentId'] ?? '').toString().trim(),
      bookingId: (json['bookingId'] ?? '').toString().trim(),
      amount: (json['amount'] ?? '').toString().trim(),
      currency: (json['currency'] ?? '').toString().trim(),
      gateway: (json['gateway'] ?? '').toString().trim(),
      paymentType: (json['paymentType'] ?? '').toString().trim(),
      referenceCode: (json['referenceCode'] ?? '').toString().trim(),
      paymentExpiresAt: _parseDateTime(json['paymentExpiresAt']),
      expiryMinutes: _toInt(json['expiryMinutes']),
      instructions: json['instructions'] is Map
          ? Map<String, dynamic>.from(json['instructions'] as Map)
          : const {},
      accountDetails: json['accountDetails'] is Map
          ? Map<String, dynamic>.from(json['accountDetails'] as Map)
          : const {},
      nextStep: json['nextStep'] is Map
          ? Map<String, dynamic>.from(json['nextStep'] as Map)
          : const {},
    );
  }

  String get instructionsAr => (instructions['ar'] ?? '').toString().trim();
  String get instructionsEn => (instructions['en'] ?? '').toString().trim();

  String get nextStepAr => (nextStep['ar'] ?? '').toString().trim();
  String get nextStepEn => (nextStep['en'] ?? '').toString().trim();

  String get normalizedGateway => gateway.trim().toUpperCase();
  String get normalizedPaymentType => paymentType.trim().toUpperCase();

  bool get hasInstructions => instructionsAr.isNotEmpty || instructionsEn.isNotEmpty;
  bool get hasNextStep => nextStepAr.isNotEmpty || nextStepEn.isNotEmpty;
  bool get hasAccountDetails => accountDetails.isNotEmpty;
}

class PaymentErrorModel {
  final String code;
  final Map<String, dynamic> message;
  final String? plainMessage;

  const PaymentErrorModel({
    required this.code,
    required this.message,
    required this.plainMessage,
  });

  String get en {
    final mapValue = (message['en'] ?? '').toString().trim();
    if (mapValue.isNotEmpty) return mapValue;
    return (plainMessage ?? '').trim();
  }

  String get ar {
    final mapValue = (message['ar'] ?? '').toString().trim();
    if (mapValue.isNotEmpty) return mapValue;
    return (plainMessage ?? '').trim();
  }

  factory PaymentErrorModel.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];

    return PaymentErrorModel(
      code: (json['code'] ?? '').toString().trim(),
      message: rawMessage is Map
          ? Map<String, dynamic>.from(rawMessage)
          : <String, dynamic>{},
      plainMessage: rawMessage is String ? rawMessage.trim() : null,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;

  final parsed = DateTime.tryParse(text);
  return parsed?.toLocal();
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}