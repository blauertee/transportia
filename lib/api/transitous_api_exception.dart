/// Failure from a MOTIS API call.
///
/// MOTIS reports problems as `{"error": "..."}` with a 4xx/5xx status, and
/// those messages are specific enough to be worth keeping (`unknown feed id
/// ""`, `enum RealtimeModeEnum: unknown value FULL`). The previous per-service
/// code discarded them and threw on the status code alone.
class TransitousApiException implements Exception {
  TransitousApiException(this.message, {this.statusCode, this.uri, this.cause});

  /// Server-supplied `error` field when present, otherwise a description of
  /// what went wrong locally.
  final String message;

  /// Null when the request never produced a response (timeout, socket error).
  final int? statusCode;

  final Uri? uri;

  /// Underlying error for transport and decoding failures.
  final Object? cause;

  bool get isTimeout => cause is TransitousTimeoutException;

  @override
  String toString() {
    final buffer = StringBuffer('TransitousApiException: $message');
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    if (uri != null) buffer.write(' [${uri!.path}]');
    return buffer.toString();
  }
}

/// Marker cause used when a request exceeds [TransitousClient.timeout].
class TransitousTimeoutException implements Exception {
  const TransitousTimeoutException(this.timeout);

  final Duration timeout;

  @override
  String toString() =>
      'TransitousTimeoutException: no response within ${timeout.inSeconds}s';
}
