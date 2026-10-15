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
      (json['warnings'] is List ? json['warnings'] as List : const [])
          .map((value) => value.toString())
          .toSet()
          .toList(),
      needsInput: json['needsInput'] is List
          ? (json['needsInput'] as List).map((value) => '$value').toList()
          : const [],
      supportedExamples: json['supportedExamples'] is List
          ? (json['supportedExamples'] as List)
          .map((value) => '$value')
          .take(4)
          .toList()
          : const [],
      requestId: json['requestId']?.toString(),
      evidence: json['evidence'] is Map
          ? Map<String, dynamic>.from(json['evidence'] as Map)
          : const {},
    );
  }
}
