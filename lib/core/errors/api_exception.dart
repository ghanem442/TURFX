class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => "ApiException($statusCode): $message";
}

class TooManyRequestsException implements Exception {
  final int retryAfter;
  final String message;

  TooManyRequestsException({
    required this.retryAfter,
    required this.message,
  });

  @override
  String toString() => "TooManyRequestsException(retryAfter: $retryAfter): $message";
}