import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'chat_data_source.dart';

class ChatApiException implements Exception {
  const ChatApiException(this.key, {this.statusCode, this.requestId, this.serverCode});
  final String key;
  final int? statusCode;
  final String? requestId;
  final String? serverCode;
  @override
  String toString() => 'ChatApiException($key, HTTP $statusCode, code=$serverCode, request=$requestId)';
}
class ChatReply {
  const ChatReply(
      this.answer,
      this.intent,
      this.warnings, {
        this.evidence = const {},
        this.needsInput = const [],
        this.supportedExamples = const [],
        this.requestId,
      });

  final String answer;
  final String intent;
  final List<String> warnings;
  final Map<String, dynamic> evidence;
  final List<String> needsInput;
  final List<String> supportedExamples;
  final String? requestId;

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      json['answer']?.toString() ?? '',
      json['intent']?.toString() ?? '',
      (json['warnings'] is List
          ? json['warnings'] as List
          : const [])
          .map((value) => value.toString())
          .toSet()
          .toList(),
      needsInput: json['needsInput'] is List ? (json['needsInput'] as List).map((v) => '$v').toList() : const [],
      supportedExamples: json['supportedExamples'] is List ? (json['supportedExamples'] as List).map((v) => '$v').take(4).toList() : const [],
      requestId: json['requestId']?.toString(),
      evidence: json['evidence'] is Map
          ? Map<String, dynamic>.from(json['evidence'] as Map)
          : const {},
    );
  }
}
class ChatApi {
  ChatApi({required this.baseUrl, http.Client? client, FirebaseAuth? auth})
      : _client = client ?? http.Client(), _auth = auth ?? FirebaseAuth.instance;
  final String baseUrl;
  final http.Client _client;
  final FirebaseAuth _auth;
  void close() => _client.close();
  Uri _uri(String path) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || !base.hasAuthority ||
        !const ['http', 'https'].contains(base.scheme)) {
      throw const ChatApiException('chat_bad_url');
    }
    // Accept either an origin or an origin ending in /api/v1.
    var prefix = base.path.replaceAll(RegExp(r'/+$'), '');
    if (prefix.endsWith('/api/v1')) prefix = prefix.substring(0, prefix.length - 7);
    return base.replace(path: '$prefix$path', query: null, fragment: null);
  }
  Future<void> checkConnection() async {
    final uri = _uri('/health');
    if (kDebugMode) debugPrint('CHAT HEALTH: $uri');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (kDebugMode) debugPrint('CHAT HEALTH HTTP: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw ChatApiException('chat_health_error', statusCode: response.statusCode);
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || !const ['healthy', 'ok'].contains(data['status'])) {
        throw const ChatApiException('chat_invalid_response');
      }
    } on FormatException {
      throw const ChatApiException('chat_invalid_response');
    } on http.ClientException {
      throw const ChatApiException('chat_connection');
    }
  }
  Future<ChatReply> ask({required String uid, required String question,
    required ChatSnapshot snapshot, required List<Map<String, dynamic>> catalog,
    List<Map<String, String>> history = const [],
    Map<String, dynamic> additionalContext = const {}}) async {
    final uri = _uri('/api/v1/chat/ask');
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) throw const ChatApiException('chat_session');
    String body;
    try {
      body = jsonEncode({
        'question': question, 'user_id': uid,
        'transactions': snapshot.transactions,
        'category_catalog': catalog, 'advisor_context': {...snapshot.context, ...additionalContext},
        'history': history.length > 6 ? history.sublist(history.length - 6) : history,
      });
    } catch (_) {
      throw const ChatApiException('chat_payload_error');
    }
    Future<http.Response> send(bool refresh) async {
      String? token;
      try { token = await user.getIdToken(refresh); }
      on FirebaseAuthException { throw const ChatApiException('chat_token'); }
      if (token == null) throw const ChatApiException('chat_token');
      if (kDebugMode) debugPrint('CHAT POST: $uri');
      try {
        return await _client.post(uri, headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        }, body: body).timeout(const Duration(seconds: 120));
      } on http.ClientException {
        throw const ChatApiException('chat_connection');
      }
    }
    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    if (_auth.currentUser?.uid != uid) throw const ChatApiException('chat_session');
    if (kDebugMode) debugPrint('CHAT POST HTTP: ${response.statusCode}');
    if (response.statusCode != 200) {
      final key = switch (response.statusCode) {
        401 => 'chat_login', 403 => 'chat_forbidden',
        404 => 'chat_endpoint_missing', 422 => 'chat_request_invalid',
        503 => 'chat_service_unavailable', _ => 'chat_server',
      };
      String? requestId;
      String? serverCode;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['detail'] is Map) {
          final detail = decoded['detail'] as Map;
          requestId = detail['requestId']?.toString();
          serverCode = detail['code']?.toString();
        }
      } catch (_) { /* An HTML/plain-text error is still an HTTP error. */ }
      throw ChatApiException(key, statusCode: response.statusCode,
          requestId: requestId, serverCode: serverCode);
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic> || json['answer'] is! String) {
        throw const ChatApiException('chat_invalid_response');
      }
      return ChatReply.fromJson(json);
    } on FormatException { throw const ChatApiException('chat_invalid_response'); }
  }
}
