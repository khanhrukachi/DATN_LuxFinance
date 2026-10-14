import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';

class DebtContactAvatar extends StatelessWidget {
  final String name;
  final bool selected;

  const DebtContactAvatar({required this.name, this.selected = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: DebtStyle.teal.withOpacity(.14),
      borderRadius: BorderRadius.circular(14),
    ),
    alignment: Alignment.center,
    child: name.trim().isEmpty
        ? Icon(
            Icons.person_add_alt_1_outlined,
            color: DebtStyle.accent(context),
          )
        : Text(
            String.fromCharCode(name.trim().runes.first).toUpperCase(),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: DebtStyle.accent(context),
            ),
          ),
  );
}
