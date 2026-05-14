/// Default REST base (must end with `/api/v1/` for this app).
const String _kDefaultApiBaseUrl =
    'https://ghanem-production.up.railway.app/api/v1/';

const String _kDefaultApiOrigin = 'https://ghanem-production.up.railway.app';

String _trimTrailingSlashes(String s) {
  var out = s.trim();
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// Full API base URL, e.g. `https://host/api/v1/`.
///
/// Compile-time: `--dart-define=API_BASE_URL=https://.../api/v1/`
/// If only [API_ORIGIN] is set (no path), `/api/v1/` is appended.
String resolveApiBaseUrl() {
  const fromBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseTrim = fromBase.trim();
  if (baseTrim.isNotEmpty) {
    return baseTrim.endsWith('/') ? baseTrim : '$baseTrim/';
  }

  const fromOrigin = String.fromEnvironment('API_ORIGIN', defaultValue: '');
  final originTrim = fromOrigin.trim();
  if (originTrim.isNotEmpty) {
    final origin = _trimTrailingSlashes(originTrim);
    return '$origin/api/v1/';
  }

  return _kDefaultApiBaseUrl;
}

/// Public site origin without trailing slash (for links, etc.).
String resolveApiOrigin() {
  const fromOrigin = String.fromEnvironment('API_ORIGIN', defaultValue: '');
  final originTrim = fromOrigin.trim();
  if (originTrim.isNotEmpty) {
    return _trimTrailingSlashes(originTrim);
  }

  const fromBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseTrim = fromBase.trim();
  if (baseTrim.isNotEmpty) {
    final normalized = baseTrim.endsWith('/') ? baseTrim : '$baseTrim/';
    final withoutApi = normalized.replaceFirst(RegExp(r'/api/v1/?$'), '');
    return _trimTrailingSlashes(withoutApi);
  }

  return _kDefaultApiOrigin;
}
