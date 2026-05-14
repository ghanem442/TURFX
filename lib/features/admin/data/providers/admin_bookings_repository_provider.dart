import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/network/providers.dart';

import '../repositories/admin_bookings_repository.dart';

final adminBookingsRepositoryProvider =
    Provider<AdminBookingsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminBookingsRepository(api);
});