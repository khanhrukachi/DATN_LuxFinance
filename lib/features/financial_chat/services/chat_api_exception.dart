class ChatApiException implements Exception {
  const ChatApiException(
    this.key, {
    this.statusCode,
    this.requestId,
    this.serverCode,
  });

  final String key;
  final int? statusCode;
  final String? requestId;
  final String? serverCode;

  @override
  String toString() =>
      'ChatApiException($key, HTTP $statusCode, code=$serverCode, request=$requestId)';
}
