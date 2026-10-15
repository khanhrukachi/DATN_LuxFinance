import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_style.dart';
import 'chat_message.dart';
import 'transaction_confirmation_card.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message, required this.saving, required this.isSaving, required this.onCancel, required this.onConfirm, required this.savingStatus});
  final ChatMessage message;
  final bool saving;
  final bool isSaving;
  final VoidCallback onCancel;
  final Future<void> Function() onConfirm;
  final Widget savingStatus;
  @override
  Widget build(BuildContext context) {
    final style = ChatStyle(context);
    final fromUser = message.fromUser;
    final isSavingThisMessage = isSaving;

    final bubbleColor = fromUser ? const Color(0xFF2DD8C6) : style.cardColor;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: fromUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        AppLocalizations.of(context).translate(
                          fromUser
                              ? 'financial_secretary_you'
                              : 'financial_secretary_assistant',
                        ),
                        style: TextStyle(fontSize: 11, color: style.mutedColor),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: fromUser ? null : bubbleColor,
                        gradient: fromUser
                            ? const LinearGradient(
                          colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
                        )
                            : null,
                        border: fromUser
                            ? null
                            : Border.all(color: style.textColor.withOpacity(.08)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(fromUser ? 20 : 5),
                          bottomRight: Radius.circular(fromUser ? 5 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              style.dark ? 0.12 : 0.06,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: fromUser
                              ? const Color(0xFF073D43)
                              : style.textColor,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (message.draft != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AbsorbPointer(
                          absorbing: saving,
                          child: ExcludeFocus(
                            excluding: saving,
                            child: Opacity(
                              opacity: saving ? 0.65 : 1,
                              child: TransactionConfirmationCard(
                                draft: message.draft!,
                                onCancel: onCancel,
                                onConfirm: onConfirm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSavingThisMessage) savingStatus,
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
