import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_financial_management/core/constants/function/debt_phone_validator.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class DebtPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  const DebtPhoneField({Key? key, required this.controller, this.onSubmitted})
    : super(key: key);

  @override
  State<DebtPhoneField> createState() => _DebtPhoneFieldState();
}

class _DebtPhoneFieldState extends State<DebtPhoneField> {
  String tr(String key) => AppLocalizations.of(context).translate(key);

  String? localizePhoneError(String? error) {
    if (error == DebtPhoneValidator.digitsError) {
      return tr('debt_phone_digits_error');
    }
    if (error == DebtPhoneValidator.formatError) {
      return tr('debt_phone_format_error');
    }
    return error;
  }

  String? inputError;

  void feedback(bool valid) {
    final next = valid ? null : DebtPhoneValidator.digitsError;
    if (mounted && next != inputError) setState(() => inputError = next);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    inputFormatters: [_PhoneDigitsFormatter(feedback)],
    maxLength: 11,
    maxLengthEnforcement: MaxLengthEnforcement.none,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (value) =>
        localizePhoneError(inputError ?? DebtPhoneValidator.validate(value)),
    onChanged: (_) {
      setState(() {});
    },
    onFieldSubmitted: widget.onSubmitted,
    decoration:
        SpendingStyle.input(
          context,
          tr('debt_phone_optional'),
          icon: Icons.phone_outlined,
          hint: tr('debt_phone_example'),
        ).copyWith(
          helperText: tr('debt_phone_helper'),
          helperMaxLines: 2,
          errorMaxLines: 3,
          errorText: inputError,
          suffixIcon: inputError != null || widget.controller.text.isNotEmpty
              ? IconButton(
                  tooltip: tr('debt_phone_clear'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    widget.controller.clear();
                    setState(() => inputError = null);
                  },
                )
              : null,
        ),
  );
}

class _PhoneDigitsFormatter extends TextInputFormatter {
  final void Function(bool valid) feedback;

  _PhoneDigitsFormatter(this.feedback);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final valid = RegExp(r'^[0-9]*$').hasMatch(newValue.text);
    feedback(valid);
    return valid
        ? newValue
        : oldValue; // Never silently remove letters from a paste.
  }
}
