import 'package:shared_preferences/shared_preferences.dart';

class PaymentLocalStore {
  static const String _paymentIdPrefix = 'booking_payment_id_';

  String _key(String bookingId) => '$_paymentIdPrefix$bookingId';

  Future<void> savePaymentId({
    required String bookingId,
    required String paymentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(bookingId), paymentId);
  }

  Future<String?> getPaymentId({
    required String bookingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(bookingId));
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> clearPaymentId({
    required String bookingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookingId));
  }
}