import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
Widget itemSpending({required IconData icon, required String text,
  required Function action, Color? color,
}) => Builder(builder: (context) => Material(
  color: Colors.transparent, borderRadius: BorderRadius.circular(16),
  clipBehavior: Clip.antiAlias,
  child: InkWell(onTap: () => action(),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SpendingFieldIcon(icon: icon), const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
              color: SpendingStyle.text(context)))),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 22, color: SpendingStyle.muted(context)),
        ])),
  ),
));
