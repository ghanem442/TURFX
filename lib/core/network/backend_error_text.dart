import 'package:dio/dio.dart';

/// Some APIs return i18n keys as plain strings (e.g. `common.error`).
String humanizeBackendErrorText(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return 'Request failed';

  switch (s) {
    case 'common.error':
      return 'حدث خطأ من السيرفر. راجع سجلات الباك اند على Railway، وتأكد أن المسارات تعمل وأنك مسجّل كمشرف.';
    case 'common.badRequest':
      return 'الطلب غير صالح أو غير مسموح به في هذه الحالة.';
    case 'common.unauthorized':
      return 'انتهت الجلسة أو التوكن غير صالح. جرّب تسجيل الخروج ثم الدخول مرة أخرى.';
    case 'common.forbidden':
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    case 'common.tooManyRequests':
      return 'طلبات كثيرة جدًا. انتظر لحظة وحاول مرة أخرى.';
    default:
      if (s.startsWith('common.')) {
        return 'رد من الخادم: $s (افتح logs الـ API على Railway لمعرفة السبب).';
      }
      return s;
  }
}

String formatDioFailure(DioException e) {
  final sc = e.response?.statusCode;
  final msg = (e.message ?? '').trim();
  if (sc != null) {
    return msg.isEmpty ? 'HTTP $sc' : 'HTTP $sc — $msg';
  }
  return msg.isEmpty ? 'Network error' : msg;
}
