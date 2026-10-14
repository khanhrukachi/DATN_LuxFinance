import 'package:flutter/material.dart';

class ChatRetryButton extends StatelessWidget {
  const ChatRetryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.refresh),
    label: Text(label),
  );
}
