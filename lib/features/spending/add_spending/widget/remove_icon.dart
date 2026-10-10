import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
Widget removeIcon({required Function action, Color? background, Color? color}) => Builder(
  builder: (context) => Material(
    color: background ?? SpendingStyle.danger.withOpacity(.12),
    borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => action(),
        child: Padding(padding: const EdgeInsets.all(8),
            child: Icon(Icons.close_rounded, size: 16, color: color ?? SpendingStyle.danger))),
  ),
);
