class ManualPaymentInfoModel {
  final String gateway;
  final bool isAvailable;
  final Map<String, dynamic> instructions;
  final Map<String, dynamic> accountDetails;

  const ManualPaymentInfoModel({
    required this.gateway,
    required this.isAvailable,
    required this.instructions,
    required this.accountDetails,
  });

  String get instructionsAr => (instructions['ar'] ?? '').toString();
  String get instructionsEn => (instructions['en'] ?? '').toString();

  factory ManualPaymentInfoModel.fromJson(Map<String, dynamic> json) {
    return ManualPaymentInfoModel(
      gateway: (json['gateway'] ?? '').toString(),
      isAvailable: json['isAvailable'] == true,
      instructions: json['instructions'] is Map
          ? Map<String, dynamic>.from(json['instructions'] as Map)
          : const {},
      accountDetails: json['accountDetails'] is Map
          ? Map<String, dynamic>.from(json['accountDetails'] as Map)
          : const {},
    );
  }
}
