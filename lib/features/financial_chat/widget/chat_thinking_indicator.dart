import 'package:flutter/material.dart';

class ChatThinkingIndicator extends StatelessWidget {
  const ChatThinkingIndicator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: dark ? const Color(0xFF2DD8C6) : const Color(0xFF14988F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.onSurface.withOpacity(.7)),
            ),
          ),
        ],
      ),
    );
  }
}
