import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TextContinue extends StatelessWidget {
  const TextContinue({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: AuthStyle.teal.withOpacity(.2))),
    const SizedBox(width: 12),
    Flexible(flex: 3, child: Text(AppLocalizations.of(context).translate('or_continue_with'),
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AuthStyle.muted(context)))),
    const SizedBox(width: 12),
    Expanded(child: Divider(color: AuthStyle.teal.withOpacity(.2))),
  ]);
}
