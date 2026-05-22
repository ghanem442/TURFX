import 'package:football/core/network/backend_error_text.dart';

String friendlyErrorMessage(Object error, {String fallback = 'حدث خطأ، حاول مرة أخرى'}) {
  final text = error.toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException [bad response]: ', '')
      .trim();

  if (text.isEmpty) return fallback;

  // Backend i18n keys
   final lower = text.toLowerCase();
  if (lower.contains('toomanyrequests') ||
      lower.contains('too many requests') ||
      text == 'common.tooManyRequests') {
    return 'طلبات كثيرة جدًا. انتظر لحظة وحاول مرة أخرى.';
  }

  // Use backend humanizer if it matches a known key
  final humanized = humanizeBackendErrorText(text);
  if (humanized != text) return humanized;

  return text;
}

String extractErrorMessage(dynamic raw, {String fallback = 'Request failed'}) {
  if (raw is Map) {
    final map = raw.cast<String, dynamic>();
    final error = map['error'];

    if (error is Map) {
      final msg = error['message'];
      if (msg is Map) {
        final ar = msg['ar']?.toString().trim();
        final en = msg['en']?.toString().trim();
        if (ar != null && ar.isNotEmpty) return ar;
        if (en != null && en.isNotEmpty) return en;
      }
      final plain = error['message']?.toString().trim();
      if (plain != null && plain.isNotEmpty) return plain;

      final details = error['details'];
      if (details is List && details.isNotEmpty) {
        for (final item in details) {
          if (item is Map) {
            final m = item['message'];
            if (m is Map) {
              final ar = m['ar']?.toString().trim();
              final en = m['en']?.toString().trim();
              if (ar != null && ar.isNotEmpty) return ar;
              if (en != null && en.isNotEmpty) return en;
            }
            final t = item['message']?.toString().trim();
            if (t != null && t.isNotEmpty) return t;
          }
          final t = item?.toString().trim();
          if (t != null && t.isNotEmpty) return t;
        }
      }
      if (details is String && details.trim().isNotEmpty) return details.trim();

      final code = error['code']?.toString().trim();
      if (code != null && code.isNotEmpty) return code;
    }

    final errors = map['errors'];
    if (errors is List && errors.isNotEmpty) {
      final joined = errors
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
      if (joined.isNotEmpty) return joined;
    }

    final message = map['message'];
    if (message is Map) {
      final ar = message['ar']?.toString().trim();
      final en = message['en']?.toString().trim();
      if (ar != null && ar.isNotEmpty) return ar;
      if (en != null && en.isNotEmpty) return en;
    }
    final plainMessage = message?.toString().trim();
    if (plainMessage != null && plainMessage.isNotEmpty) return plainMessage;
  }

  if (raw is String && raw.trim().isNotEmpty) return raw.trim();

  return fallback;
}
