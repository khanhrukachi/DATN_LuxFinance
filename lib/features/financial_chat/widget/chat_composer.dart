import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSubmit,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSubmit;
  final VoidCallback onSend;

  static const _teal = Color(0xFF2DD8C6);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF0E1C22)
        : const Color(0xFFF3F9FA);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _teal.withOpacity(.12)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('financial_chat_input_hint'),
                    counterText: '',
                    filled: true,
                    fillColor: background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final isEnabled = canSubmit && value.text.trim().isNotEmpty;
                  final label = AppLocalizations.of(context).translate('financial_chat_send_message');
                  return Semantics(
                    label: label,
                    button: true,
                    child: Tooltip(
                      message: label,
                      child: Material(
                        color: isEnabled
                            ? _teal
                            : colors.onSurface.withOpacity(.12),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isEnabled ? onSend : null,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: isEnabled
                                  ? const Color(0xFF073D43)
                                  : colors.onSurface.withOpacity(.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('financial_chat_footer'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: colors.onSurface.withOpacity(.5),
            ),
          ),
        ],
      ),
    );
  }
}
