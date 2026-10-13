import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'debt_helpers.dart';

class DebtDetailActions extends StatelessWidget {
  final VoidCallback onEdit, onDelete;

  const DebtDetailActions({
    Key? key,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          SizedBox(
            width: box.maxWidth < 300 ? box.maxWidth : (box.maxWidth - 12) / 2,
            child: _button(
              context,
              debtTranslate(context, 'debt_edit'),
              Icons.edit_rounded,
              SpendingStyle.accent(context),
              onEdit,
            ),
          ),
          SizedBox(
            width: box.maxWidth < 300 ? box.maxWidth : (box.maxWidth - 12) / 2,
            child: _button(
              context,
              debtTranslate(context, 'debt_delete'),
              Icons.delete_outline_rounded,
              SpendingStyle.danger,
              onDelete,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _button(
    BuildContext context,
    String text,
    IconData icon,
    Color color,
    VoidCallback action,
  ) => Material(
    color: color.withOpacity(.08),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: action,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
