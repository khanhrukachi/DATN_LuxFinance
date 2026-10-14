import 'package:flutter/material.dart';

class ChatEvidenceLine extends StatelessWidget {
  const ChatEvidenceLine({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(body, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}
