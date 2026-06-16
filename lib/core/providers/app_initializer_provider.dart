import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_session_provider.dart';
import '../notifications/notifications_provider.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final notifications = ref.read(notificationsServiceProvider);

  await notifications.initialize();
});
