import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'chat_suggestion_tile.dart';

class ChatWelcome extends StatelessWidget {
  const ChatWelcome({super.key, required this.onSend});

  final ValueChanged<String> onSend;

  static const _cyan = Color(0xFF00D2FF);
  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [_cyan, _teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    String translate(String key) => AppLocalizations.of(context).translate(key);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [const Color(0xFF163A46), const Color(0xFF16463F)]
                  : [const Color(0xFFE1F7FF), const Color(0xFFDCF9F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _teal.withOpacity(.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: _gradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withOpacity(.22),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF073D43),
                  size: 28,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                translate('chat_welcome_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                translate('chat_welcome'),
                style: TextStyle(
                  color: colors.onSurface.withOpacity(.68),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text(
          translate('chat_suggestions'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colors.onSurface.withOpacity(.75),
          ),
        ),
        const SizedBox(height: 14),
        ChatSuggestionTile(
          title: translate('chat_q_summary'),
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => onSend(translate('chat_q_summary')),
        ),
        ChatSuggestionTile(
          title: translate('chat_q_budget'),
          icon: Icons.savings_outlined,
          onTap: () => onSend(translate('chat_q_budget')),
        ),
        ChatSuggestionTile(
          title: translate('chat_q_forecast'),
          icon: Icons.trending_up_rounded,
          onTap: () => onSend(translate('chat_q_forecast')),
        ),
      ],
    );
  }
}
