import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/network/providers.dart';

import '../repositories/admin_payments_repository.dart';

final adminPaymentsRepositoryProvider =
    Provider<AdminPaymentsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminPaymentsRepository(api);
});