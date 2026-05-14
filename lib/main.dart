import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/notifications_provider.dart';
import 'core/notifications/push_token_sync_service.dart';
import 'features/auth/presentation/providers/auth_session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrapFirebase();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(
    () {
      runApp(const ProviderScope(child: _BootApp()));
    },
    (error, stack) {
      debugPrint('Zoned error: $error');
      debugPrint('$stack');
    },
  );
}

class _BootApp extends ConsumerStatefulWidget {
  const _BootApp();

  @override
  ConsumerState<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends ConsumerState<_BootApp> {
  bool _notificationsInitialized = false;
  bool _pushTokenSyncInitialized = false;

  @override
  void initState() {
    super.initState();

    ref.listenManual<AuthStatus>(authSessionProvider, (_, next) async {
      if (!isFirebaseAvailable) return;
      if (next == AuthStatus.authenticated) {
        try {
          await ref.read(pushTokenSyncServiceProvider).syncNow();
        } catch (e, stack) {
          debugPrint('Push token sync on auth change error: $e');
          debugPrint('$stack');
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isFirebaseAvailable) return;

      if (_notificationsInitialized) return;
      _notificationsInitialized = true;

      try {
        await ref.read(notificationsServiceProvider).initialize();
        await ref.read(pushTokenSyncServiceProvider).syncNow();
      } catch (e, stack) {
        debugPrint('Notifications init error: $e');
        debugPrint('$stack');
      }

      if (_pushTokenSyncInitialized) return;
      _pushTokenSyncInitialized = true;

      try {
        await ref.read(pushTokenSyncServiceProvider).initialize();
      } catch (e, stack) {
        debugPrint('Push token sync init error: $e');
        debugPrint('$stack');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}
