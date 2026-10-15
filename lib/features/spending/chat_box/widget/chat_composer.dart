import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_style.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({super.key, required this.controller, required this.focusNode, required this.saving, required this.onSend});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool saving;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) {
    final style = ChatStyle(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: style.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: style.dark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !saving,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(color: style.textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: saving
                      ? AppLocalizations.of(context).translate('financial_secretary_saving_input_hint')
                      : AppLocalizations.of(context).translate('financial_secretary_input_hint'),
                  hintStyle: TextStyle(color: style.mutedColor, fontSize: 13),
                  prefixIcon: Icon(Icons.edit_note_rounded, color: style.mutedColor),
                  filled: true,
                  fillColor: style.pageColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: style.dark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFF2DD8C6),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                tooltip: AppLocalizations.of(context).translate('financial_secretary_send_message'),
                onPressed: saving ? null : onSend,
                color: const Color(0xFF073D43),
                disabledColor: Colors.white54,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
    }
}
