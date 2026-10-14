import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';

class DebtActionButton extends StatelessWidget {
  const DebtActionButton({super.key, required this.label, this.onPressed,
    this.icon = Icons.check_rounded});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => FinanceActionButton(
    label: label, icon: icon, onPressed: onPressed,
  );
}
