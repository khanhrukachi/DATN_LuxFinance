class ChatSnapshot {
  const ChatSnapshot(this.transactions, this.context);

  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> context;
}
