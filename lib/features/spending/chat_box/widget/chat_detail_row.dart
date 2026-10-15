import 'package:flutter/material.dart';

/// One label/value row in the transaction confirmation card.
class ChatDetailRow extends StatelessWidget {
  const ChatDetailRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
