import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';

final pushTokenSyncServiceProvider = Provider<PushTokenSyncService>((ref) {
  final api = ref.watch(apiClientProvider);
  return PushTokenSyncService(ref, api);
});

class PushTokenSyncService {
  PushTokenSyncService(this._ref, this._api);

  final Ref _ref;
  final dynamic _api;

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _lastRegisteredToken;
  String? _lastRegisteredUserId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _registerIfPossible();

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        if (kDebugMode) {
          debugPrint('[FCM] onTokenRefresh -> $token');
        }
        await _registerIfPossible(forcedToken: token);
      },
      onError: (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[FCM] onTokenRefresh error: $error');
          debugPrint('$stackTrace');
        }
      },
    );
  }

  Future<void> syncNow() async {
    await _registerIfPossible();
  }

  Future<void> _registerIfPossible({String? forcedToken}) async {
    try {
      final authStatus = _ref.read(authSessionProvider);
      final user = _ref.read(authUserProvider);

      if (authStatus != AuthStatus.authenticated || user == null) {
        if (kDebugMode) {
          debugPrint('[FCM] Skip register: user not authenticated');
        }
        return;
      }

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('[FCM] permission status -> ${settings.authorizationStatus}');
      }

      final token = forcedToken ?? await FirebaseMessaging.instance.getToken();

      if (token == null || token.trim().isEmpty) {
        if (kDebugMode) {
          debugPrint('[FCM] Token is null/empty');
        }
        return;
      }

      final userId = (user.id ?? '').trim();

      if (_lastRegisteredToken == token && _lastRegisteredUserId == userId) {
        if (kDebugMode) {
          debugPrint('[FCM] Token already registered for same user');
        }
        return;
      }

      final deviceId = _buildDeviceId(userId);

      final res = await _api.post(
        'notifications/register-device',
        data: {
          'token': token,
          'deviceId': deviceId,
        },
      );

      if (kDebugMode) {
        debugPrint('[FCM] register-device status -> ${res.statusCode}');
        debugPrint('[FCM] register-device response -> ${res.data}');
      }

      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
        _lastRegisteredToken = token;
        _lastRegisteredUserId = userId;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[FCM] register-device failed: $e');
        debugPrint('$stackTrace');
      }
    }
  }

  String _buildDeviceId(String userId) {
    if (kIsWeb) {
      return 'web_${userId.isEmpty ? "guest" : userId}';
    }

    if (Platform.isAndroid) {
      return 'android_${userId.isEmpty ? "guest" : userId}';
    }

    if (Platform.isIOS) {
      return 'ios_${userId.isEmpty ? "guest" : userId}';
    }

    return 'device_${userId.isEmpty ? "guest" : userId}';
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}