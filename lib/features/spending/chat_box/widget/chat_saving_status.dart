import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_style.dart';

class ChatSavingStatus extends StatelessWidget {
  const ChatSavingStatus({super.key, required this.dotCount});
  final int dotCount;
  @override
  Widget build(BuildContext context) {
    final style = ChatStyle(context);
    final color = style.dark ? Colors.tealAccent : const Color(0xFF008F7A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Semantics(
        liveRegion: true,
        label: AppLocalizations.of(context).translate('financial_secretary_saving_announcement'),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).translate('financial_secretary_saving_status'),
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  List.filled(dotCount, '.').join(),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    }
}
