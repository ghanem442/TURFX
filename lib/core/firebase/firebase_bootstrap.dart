import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:football/firebase_options.dart';

bool _firebaseReady = false;

/// Whether [Firebase.initializeApp] completed for this process.
bool get isFirebaseAvailable => _firebaseReady;

/// Initializes Firebase on Android, iOS, and Web only (desktop is skipped
/// until `flutterfire configure` adds options for those targets).
Future<void> bootstrapFirebase() async {
  final options = _firebaseOptionsForCurrentPlatform();
  if (options == null) {
    debugPrint(
      'Firebase: skipped on $defaultTargetPlatform (no DefaultFirebaseOptions).',
    );
    _firebaseReady = false;
    return;
  }

  if (Firebase.apps.isNotEmpty) {
    _firebaseReady = true;
    return;
  }

  await Firebase.initializeApp(options: options);
  _firebaseReady = true;
}

FirebaseOptions? _firebaseOptionsForCurrentPlatform() {
  if (kIsWeb) {
    return DefaultFirebaseOptions.web;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return DefaultFirebaseOptions.android;
    case TargetPlatform.iOS:
      return DefaultFirebaseOptions.ios;
    default:
      return null;
  }
}
