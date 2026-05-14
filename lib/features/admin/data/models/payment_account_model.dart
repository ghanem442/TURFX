class PaymentAccountModel {
  final String gateway;
  final bool isEnabled;
  final String mobileNumber;
  final String accountName;
  final String instructionsAr;
  final String instructionsEn;

  const PaymentAccountModel({
    required this.gateway,
    required this.isEnabled,
    required this.mobileNumber,
    required this.accountName,
    required this.instructionsAr,
    required this.instructionsEn,
  });

  factory PaymentAccountModel.fromJson(Map<String, dynamic> json) {
    return PaymentAccountModel(
      gateway: (json['gateway'] ?? '').toString(),
      isEnabled: json['isEnabled'] == true,
      mobileNumber: (json['mobileNumber'] ?? '').toString(),
      accountName: (json['accountName'] ?? '').toString(),
      instructionsAr: (json['instructionsAr'] ?? '').toString(),
      instructionsEn: (json['instructionsEn'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gateway': gateway,
      'isEnabled': isEnabled,
      'mobileNumber': mobileNumber.trim(),
      'accountName': accountName.trim(),
      'instructionsAr': instructionsAr.trim(),
      'instructionsEn': instructionsEn.trim(),
    };
  }

  PaymentAccountModel copyWith({
    String? gateway,
    bool? isEnabled,
    String? mobileNumber,
    String? accountName,
    String? instructionsAr,
    String? instructionsEn,
  }) {
    return PaymentAccountModel(
      gateway: gateway ?? this.gateway,
      isEnabled: isEnabled ?? this.isEnabled,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      accountName: accountName ?? this.accountName,
      instructionsAr: instructionsAr ?? this.instructionsAr,
      instructionsEn: instructionsEn ?? this.instructionsEn,
    );
  }
}
