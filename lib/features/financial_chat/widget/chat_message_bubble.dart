import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/financial_chat/models/chat_message.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'chat_evidence_card.dart';
import 'monthly_comparison_chart.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.onExampleTap,
    required this.exampleEnabled,
    this.categoryCatalog = const [],
  });

  final ChatMessage message;
  final ValueChanged<String> onExampleTap;
  final bool exampleEnabled;
  final List<Map<String, dynamic>> categoryCatalog;

  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [Color(0xFF00D2FF), _teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF172A30) : Colors.white;
    final error = message.errorKey != null;
    final background = error
        ? colors.errorContainer
        : message.user
        ? _teal
        : card;
    final foreground = error
        ? colors.onErrorContainer
        : message.user
        ? const Color(0xFF073D43)
        : colors.onSurface;
    final maximumWidth = MediaQuery.of(context).size.width * .86;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maximumWidth),
          child: Column(
            crossAxisAlignment: message.user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                child: Text(
                  AppLocalizations.of(context).translate(message.user ? 'financial_chat_you' : 'financial_chat_assistant'),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withOpacity(.6),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: message.user ? null : background,
                  gradient: message.user ? _gradient : null,
                  borderRadius: BorderRadius.circular(20),
                  border: message.user
                      ? null
                      : Border.all(color: colors.onSurface.withOpacity(.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      error
                          ? AppLocalizations.of(context).translate(message.errorKey!)
                          : message.text.isEmpty
                          ? AppLocalizations.of(context).translate('financial_chat_no_answer')
                          : message.text,
                      textAlign: TextAlign.left,
                      style: TextStyle(color: foreground, height: 1.55),
                    ),
                    if (message.warnings.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          height: 1,
                          color: foreground.withOpacity(.15),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context).translate('financial_chat_notes'),
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final warning in message.warnings)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            AppLocalizations.of(context).translate('financial_chat_warning_item').replaceAll('{warning}', warning),
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              color: foreground.withOpacity(.75),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                    if (!message.user && message.evidence.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ChatEvidenceCard(evidence: message.evidence, categoryCatalog: categoryCatalog),
                    ],
                    for (final example in message.examples)
                      TextButton(
                        onPressed: exampleEnabled
                            ? () => onExampleTap(example)
                            : null,
                        child: Text(example),
                      ),
                    if (!message.user &&
                        message.evidence['current'] is Map &&
                        message.evidence['previous'] is Map) ...[
                      const SizedBox(height: 16),
                      MonthlyComparisonChart(evidence: message.evidence),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
