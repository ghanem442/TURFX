import 'package:flutter_test/flutter_test.dart';
import 'package:football/core/network/base_url.dart';

void main() {
  test('resolveApiBaseUrl returns production default', () {
    final url = resolveApiBaseUrl();
    expect(url, contains('railway.app'));
    expect(url.endsWith('/'), isTrue);
  });

  test('resolveApiOrigin returns host without trailing slash', () {
    final origin = resolveApiOrigin();
    expect(origin, isNot(endsWith('/')));
    expect(origin, contains('http'));
  });
}
