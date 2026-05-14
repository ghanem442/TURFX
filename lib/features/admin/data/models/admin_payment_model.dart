class AdminPaymentModel {
  final String id;
  final String bookingId;

  final double amount;
  final String gateway;

  final String? screenshotUrl;
  final String? playerNotes;

  final String playerName;
  final String playerEmail;
  final String playerPhone;

  final String bookingNumber;
  final String fieldName;

  final DateTime createdAt;

  const AdminPaymentModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.gateway,
    required this.screenshotUrl,
    required this.playerNotes,
    required this.playerName,
    required this.playerEmail,
    required this.playerPhone,
    required this.bookingNumber,
    required this.fieldName,
    required this.createdAt,
  });

  factory AdminPaymentModel.fromJson(Map<String, dynamic> json) {
    final player = json['player'] ?? {};
    final booking = json['booking'] ?? {};

    return AdminPaymentModel(
      id: json['id'],
      bookingId: json['bookingId'],

      amount: double.tryParse(json['amount'].toString()) ?? 0,
      gateway: json['gateway'] ?? '',

      screenshotUrl: json['screenshotUrl'],
      playerNotes: json['playerNotes'],

      playerName: player['name'] ?? '',
      playerEmail: player['email'] ?? '',
      playerPhone: player['phoneNumber'] ?? '',

      bookingNumber: booking['bookingNumber'] ?? '',
      fieldName: booking['fieldName'] ?? '',

      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}