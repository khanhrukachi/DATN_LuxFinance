import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
class InputMoney extends StatelessWidget {
  const InputMoney({Key? key, required this.controller}) : super(key: key);
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    // Keep the existing formatter API and Vietnamese grouping used by the app.
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: SpendingStyle.decoration(context, hero: true),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyTextInputFormatter(formatter)],
        textAlign: TextAlign.right,
        cursorColor: SpendingStyle.accent(context),
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: SpendingStyle.text(context)),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Icon(Icons.payments_outlined, color: SpendingStyle.accent(context)),
          suffixText: '₫',
          suffixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SpendingStyle.accent(context)),
          hintText: '100.000',
          hintStyle: TextStyle(fontSize: 26, color: SpendingStyle.muted(context).withOpacity(.4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }
}
