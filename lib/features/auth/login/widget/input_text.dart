import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class InputText extends StatelessWidget {
  const InputText({
    Key? key,
    required this.hint,
    this.error,
    required this.controller,
    required this.validator,
    this.inputType,
    this.textCapitalization = TextCapitalization.none,
  }) : super(key: key);

  final String hint;
  final String? error;
  final TextEditingController controller;
  final int validator;
  final TextInputType? inputType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 15, color: AuthStyle.text(context)),
      keyboardType: inputType,
      textCapitalization: textCapitalization,
      validator: (value) {
        if (validator == 0 &&
            ((value ?? '').trim().isEmpty ||
                !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                    .hasMatch(value ?? ''))) {
          return AppLocalizations.of(context).translate('enter_valid_email');
        } else if (validator == 1 && (value ?? '').trim().isEmpty) {
          return AppLocalizations.of(context).translate('enter_valid_name');
        } else if (validator == 2 && (value ?? '').trim().isEmpty) {
          return AppLocalizations.of(context).translate('enter_valid_OTP');
        }
        return null;
      },
      decoration: AuthStyle.input(context, hint, error: error,
          icon: inputType == TextInputType.emailAddress ? Icons.alternate_email_rounded
              : validator == 1 ? Icons.person_outline_rounded : Icons.edit_outlined),
    );
  }
}
