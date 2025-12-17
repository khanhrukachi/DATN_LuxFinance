import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TextContinue extends StatelessWidget {
  const TextContinue({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Colors.black,
            endIndent: 10,
            indent: 20,
          ),
        ),
        Text(
          AppLocalizations.of(context).translate('or_continue_with'),
          style: AppStyles.p,
        ),
        const Expanded(
          child: Divider(
            color: Colors.black,
            endIndent: 20,
            indent: 10,
          ),
        ),
      ],
    );
  }
}
