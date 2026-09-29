import 'package:flutter/foundation.dart';

enum ChatTransactionKind { expense, income }

@immutable
class ChatTransactionDraft {
  final double amount;
  final int type;
  final String typeName;
  final DateTime date;
  final String note;
  final String location;
  final bool hasExplicitTime;
  final ChatTransactionKind kind;
  final double confidence;

  const ChatTransactionDraft({
    required this.amount,
    required this.type,
    required this.typeName,
    required this.date,
    required this.note,
    this.location = '',
    this.hasExplicitTime = false,
    required this.kind,
    required this.confidence,
  });

  int get signedMoney => kind == ChatTransactionKind.expense
      ? -amount.round()
      : amount.round();
}

@immutable
class ChatParseResult {
  final ChatTransactionDraft? draft;
  final String? question;
  final String? error;

  const ChatParseResult._({this.draft, this.question, this.error});

  factory ChatParseResult.success(ChatTransactionDraft draft) =>
      ChatParseResult._(draft: draft);

  factory ChatParseResult.question(String message) =>
      ChatParseResult._(question: message);

  factory ChatParseResult.error(String message) =>
      ChatParseResult._(error: message);
}
