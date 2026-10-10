import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
Widget inputSpending({
  required IconData icon, required Color color,
  required TextEditingController controller, required String hintText,
  Function(String value)? action, TextInputAction? textInputAction,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
}) => Builder(builder: (context) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(children: [
    SpendingFieldIcon(icon: icon),
    const SizedBox(width: 12),
    Expanded(child: TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 15, color: SpendingStyle.text(context)),
      cursorColor: SpendingStyle.accent(context),
      keyboardType: keyboardType,
      maxLines: keyboardType == TextInputType.multiline ? null : 1,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onFieldSubmitted: action,
      decoration: InputDecoration(border: InputBorder.none,
          enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          hintText: hintText, hintStyle: TextStyle(color: SpendingStyle.muted(context)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12)),
    )),
  ]),
));
