import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class InputPassword extends StatelessWidget {
  const InputPassword({
    Key? key,
    required this.hint,
    this.error,
    required this.controller,
    this.password,
    required this.hide,
    required this.action,
  }) : super(key: key);

  final String hint;
  final String? error;
  final TextEditingController controller;
  final TextEditingController? password;
  final bool hide;
  final Function action;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: hide,
      style: TextStyle(fontSize: 15, color: AuthStyle.text(context)),
      validator: (value) {
        if (password != null &&
            password!.text.toString() != controller.text.toString() ||
            password != null && (value ?? '').isEmpty) {
          return AppLocalizations.of(context)
              .translate('enter_valid_confirm_password');
        }

        if ((value ?? '').isEmpty && password == null) {
          return AppLocalizations.of(context).translate('enter_valid_password');
        }

        return null;
      },
      enableSuggestions: false,
      autocorrect: false,
      decoration: AuthStyle.input(context, hint, error: error,
          icon: Icons.lock_outline_rounded,
          suffix: IconButton(
            onPressed: () { action(); },
            color: AuthStyle.accent(context),
            icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 21),
          )),
    );
  }
}
