import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_style.dart';
import 'chat_avatar.dart';

class ChatWelcome extends StatelessWidget {
  const ChatWelcome({super.key, required this.greeting});
  final String greeting;
  @override
  Widget build(BuildContext context) {
    final style = ChatStyle(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.dark
              ? [const Color(0xFF163A46), const Color(0xFF16463F)]
              : [const Color(0xFFE1F7FF), const Color(0xFFDCF9F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF2DD8C6).withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatAvatar(size: 54),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).translate('financial_secretary_title'),
            style: TextStyle(
              color: style.textColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            greeting,
            textAlign: TextAlign.justify,
            style: TextStyle(color: style.mutedColor, height: 1.6),
          ),
        ],
      ),
    );
  }
}
