import 'package:flutter/material.dart';

class ChatEvidenceSection extends StatelessWidget {
  const ChatEvidenceSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: [
        for (final child in children)
          SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}
