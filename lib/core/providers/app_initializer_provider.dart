import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_session_provider.dart';
import '../firebase/firebase_bootstrap.dart';
import '../notifications/notifications_provider.dart';
import '../notifications/push_token_sync_service.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  if (!isFirebaseAvailable) return;

  final notifications = ref.read(notificationsServiceProvider);
  final pushTokenService = ref.read(pushTokenSyncServiceProvider);

  await notifications.initialize();
  await pushTokenService.initialize();
  await pushTokenService.syncNow();

  ref.listen<AuthStatus>(authSessionProvider, (_, next) async {
    if (next == AuthStatus.authenticated) {
      try {
        await pushTokenService.syncNow();
      } catch (e, stack) {
        debugPrint('Push token sync on auth change error: $e');
        debugPrint('$stack');
      }
    }
  });
});
