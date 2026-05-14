import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/payment_local_store.dart';

final paymentLocalStoreProvider = Provider<PaymentLocalStore>((ref) {
  return PaymentLocalStore();
});