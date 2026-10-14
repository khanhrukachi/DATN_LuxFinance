import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_reply.dart';
import '../models/chat_snapshot.dart';
import 'chat_api_exception.dart';

class ChatApi {
  ChatApi({required this.baseUrl, http.Client? client, FirebaseAuth? auth})
    : _client = client ?? http.Client(),
      _auth = auth ?? FirebaseAuth.instance;
  final String baseUrl;
  final http.Client _client;
  final FirebaseAuth _auth;

  void close() => _client.close();

  Uri _uri(String path) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        !base.hasAuthority ||
        !const ['http', 'https'].contains(base.scheme)) {
      throw const ChatApiException('chat_bad_url');
    }
    var prefix = base.path.replaceAll(RegExp(r'/+$'), '');
    if (prefix.endsWith('/api/v1')) {
      prefix = prefix.substring(0, prefix.length - 7);
    }
    return base.replace(path: '$prefix$path', query: null, fragment: null);
  }

  Future<void> checkConnection() async {
    final uri = _uri('/health');
    if (kDebugMode) debugPrint('CHAT HEALTH: $uri');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (kDebugMode) debugPrint('CHAT HEALTH HTTP: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw ChatApiException(
          'chat_health_error',
          statusCode: response.statusCode,
        );
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

  Future<ChatReply> ask({
    required String uid,
    required String question,
    required ChatSnapshot snapshot,
    required List<Map<String, dynamic>> catalog,
    List<Map<String, String>> history = const [],
    Map<String, dynamic> additionalContext = const {},
  }) async {
    final uri = _uri('/api/v1/chat/ask');
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) {
      throw const ChatApiException('chat_session');
    }
    String body;
    try {
      body = jsonEncode({
        'question': question,
        'user_id': uid,
        'transactions': snapshot.transactions,
        'category_catalog': catalog,
        'advisor_context': {...snapshot.context, ...additionalContext},
        'history': history.length > 6
            ? history.sublist(history.length - 6)
            : history,
      });
    } catch (_) {
      throw const ChatApiException('chat_payload_error');
    }
    Future<http.Response> send(bool refresh) async {
      String? token;
      try {
        token = await user.getIdToken(refresh);
      } on FirebaseAuthException {
        throw const ChatApiException('chat_token');
      }
      if (token == null) throw const ChatApiException('chat_token');
      if (kDebugMode) debugPrint('CHAT POST: $uri');
      try {
        return await _client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': 'Bearer $token',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 120));
      } on http.ClientException {
        throw const ChatApiException('chat_connection');
      }
    }

    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    if (_auth.currentUser?.uid != uid) {
      throw const ChatApiException('chat_session');
    }
    if (kDebugMode) debugPrint('CHAT POST HTTP: ${response.statusCode}');
    if (response.statusCode != 200) {
      final key = switch (response.statusCode) {
        401 => 'chat_login',
        403 => 'chat_forbidden',
        404 => 'chat_endpoint_missing',
        422 => 'chat_request_invalid',
        503 => 'chat_service_unavailable',
        _ => 'chat_server',
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
      } catch (_) {
        /* An HTML/plain-text error is still an HTTP error. */
      }
      throw ChatApiException(
        key,
        statusCode: response.statusCode,
        requestId: requestId,
        serverCode: serverCode,
      );
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic> || json['answer'] is! String) {
        throw const ChatApiException('chat_invalid_response');
      }
      return ChatReply.fromJson(json);
    } on FormatException {
      throw const ChatApiException('chat_invalid_response');
    }
  }
}
