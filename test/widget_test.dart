import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/app.dart';

void main() {
  testWidgets('MyApp mounts', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  });
}
