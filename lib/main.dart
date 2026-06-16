import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error');
    debugPrint('$stack');
    return true;
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(const ProviderScope(child: MyApp()));
}
