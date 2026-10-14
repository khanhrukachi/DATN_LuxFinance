import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';

class DebtSaveAction extends StatelessWidget {
  const DebtSaveAction({super.key, required this.label, this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FinanceToolbarButton(
    tooltip: label,
    icon: Icons.check_rounded,
    onPressed: onPressed,
    loading: loading,
  );
}
