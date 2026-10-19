import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_style.dart';
import '../model/chat_intent.dart';

class ChatSuggestions extends StatelessWidget {
  const ChatSuggestions({super.key, required this.memory, required this.hasDraft, required this.saving, required this.onSelected});
  final ChatConversationMemory memory;
  final bool hasDraft;
  final bool saving;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final style = ChatStyle(context);
    final suggestions = memory.categoryCandidates.isNotEmpty
        ? memory.categoryCandidates.take(4).map((key) =>
        AppLocalizations.of(context).translate(key)).toList()
        : memory.isActive
        ? (hasDraft
        ? [
      AppLocalizations.of(context).translate('financial_secretary_save_transaction'),
      AppLocalizations.of(context).translate('financial_secretary_cancel'),
      AppLocalizations.of(context).translate('financial_secretary_new_transaction'),
    ]
        : (memory.amount == null
        ? [AppLocalizations.of(context).translate('financial_secretary_suggestion_amount_small'), AppLocalizations.of(context).translate('financial_secretary_suggestion_amount_large'), AppLocalizations.of(context).translate('financial_secretary_cancel')]
        : [
      AppLocalizations.of(context).translate('financial_secretary_suggestion_groceries_category'),
      AppLocalizations.of(context).translate('financial_secretary_suggestion_food_category'),
      AppLocalizations.of(context).translate('financial_secretary_suggestion_salary_category'),
    ]))
        : [
      AppLocalizations.of(context).translate('financial_secretary_suggestion_groceries'),
      AppLocalizations.of(context).translate('financial_secretary_suggestion_taxi'),
      AppLocalizations.of(context).translate('financial_secretary_suggestion_salary'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: List.generate(suggestions.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == suggestions.length - 1 ? 0 : 8,
            ),
            child: ActionChip(
              onPressed: saving
                  ? null
                  : () => onSelected(suggestions[index]),
              avatar: Icon(
                index == 2 ? Icons.payments_rounded : Icons.add_circle_outline,
                size: 16,
                color: style.dark ? Colors.tealAccent : const Color(0xFF008F7A),
              ),
              label: Text(suggestions[index]),
              labelStyle: TextStyle(color: style.textColor, fontSize: 12),
              backgroundColor: style.cardColor,
              side: BorderSide(color: style.dark ? Colors.white12 : Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }),
      ),
    );
  }
}
