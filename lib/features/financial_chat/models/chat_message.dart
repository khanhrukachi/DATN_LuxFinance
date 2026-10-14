class ChatMessage {
  const ChatMessage(
    this.text, {
    this.user = false,
    this.errorKey,
    this.warnings = const [],
    this.evidence = const {},
    this.examples = const [],
  });

  final String text;
  final bool user;
  final String? errorKey;
  final List<String> warnings;
  final Map<String, dynamic> evidence;
  final List<String> examples;
}
