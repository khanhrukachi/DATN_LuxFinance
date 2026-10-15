import 'package:flutter/material.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({super.key, required this.controller, required this.messageCount, required this.messageBuilder});
  final ScrollController controller;
  final int messageCount;
  final IndexedWidgetBuilder messageBuilder;
  @override
  Widget build(BuildContext context) {

    return ListView.builder(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      itemCount: messageCount,
      itemBuilder: messageBuilder,
    );
    }
}
