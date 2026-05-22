import 'base_url.dart';

/// Public origin for uploaded media (images, QR files, etc.).
///
/// Optional: `--dart-define=MEDIA_ORIGIN=https://cdn.example.com`
/// Falls back to [resolveApiOrigin].
String resolveMediaOrigin() {
  const fromEnv = String.fromEnvironment('MEDIA_ORIGIN', defaultValue: '');
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return _trimTrailingSlashes(trimmed);
  }
  return resolveApiOrigin();
}

String _trimTrailingSlashes(String s) {
  var out = s.trim();
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

bool _isPrivateOrLoopbackHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '127.0.0.1' || h == '0.0.0.0' || h == '10.0.2.2') {
    return true;
  }
  if (h.startsWith('192.168.')) return true;
  if (h.startsWith('10.')) return true;

  // RFC1918 172.16.0.0 – 172.31.255.255
  if (h.startsWith('172.')) {
    final parts = h.split('.');
    if (parts.length >= 2) {
      final second = int.tryParse(parts[1]);
      if (second != null && second >= 16 && second <= 31) return true;
    }
  }
  return false;
}

String? _filenameFromPath(String path) {
  final p = path.trim();
  if (p.isEmpty) return null;
  final segments = p.split('/').where((s) => s.trim().isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return segments.last;
}

/// Makes image/document URLs returned by the API loadable on a real device.
///
/// Handles:
/// - `/uploads/...` or `uploads/...`
/// - `http://localhost:3000/uploads/...` (rewritten to [resolveMediaOrigin])
/// - `//cdn.example.com/...`
String resolvePublicMediaUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';

  if (s.startsWith('//')) {
    return 'https:$s';
  }

  final origin = resolveMediaOrigin();

  if (s.startsWith('/')) {
    return '$origin$s';
  }

  // `uploads/field-abc.jpg` without leading slash
  if (!s.contains('://') && s.contains('/')) {
    return '$origin/${s.startsWith('uploads/') || s.startsWith('files/') || s.startsWith('storage/') ? s : 'uploads/$s'}';
  }

  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    if (s.contains('.')) {
      return '$origin/uploads/$s';
    }
    return s;
  }

  if (!_isPrivateOrLoopbackHost(uri.host)) {
    return s;
  }

  final path = uri.path.isEmpty ? '/' : uri.path;
  final q = uri.hasQuery ? '?${uri.query}' : '';
  return '$origin$path$q';
}

/// Candidate URLs to try when loading a field image (API quirks / legacy data).
List<String> buildFieldImageLoadUrls({
  required String raw,
  String? fieldId,
  String? imageId,
}) {
  final primary = resolvePublicMediaUrl(raw);
  final out = <String>[];

  void add(String? url) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return;
    if (!out.contains(u)) out.add(u);
  }

  add(primary);

  final uri = Uri.tryParse(raw.trim());
  final path = uri?.path ?? raw.trim();
  final filename = _filenameFromPath(path);

  final origin = resolveMediaOrigin();
  final apiBase = resolveApiBaseUrl();

  if (filename != null) {
    add('$origin/uploads/$filename');
    add('$apiBase/uploads/$filename');
    add('$origin/files/$filename');
    add('$origin/storage/uploads/$filename');
  }

  final fid = fieldId?.trim() ?? '';
  final iid = imageId?.trim() ?? '';
  if (fid.isNotEmpty && iid.isNotEmpty) {
    add('$apiBase/fields/$fid/images/$iid');
    add('$apiBase/fields/$fid/images/$iid/file');
    add('$apiBase/fields/$fid/images/$iid/download');
    add('$origin/api/v1/fields/$fid/images/$iid');
  }

  return out;
}
