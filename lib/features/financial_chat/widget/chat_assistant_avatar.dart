import 'package:flutter/material.dart';

class ChatAssistantAvatar extends StatelessWidget {
  const ChatAssistantAvatar({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00D2FF).withOpacity(.22),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(Icons.insights_rounded, color: const Color(0xFF073D43), size: size * .53),
  );
}
