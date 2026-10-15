import '../model/chat_intent.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final ChatTransactionDraft? draft;

  const ChatMessage({required this.text, required this.fromUser, this.draft});
}
