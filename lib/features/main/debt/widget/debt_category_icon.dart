import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'debt_category_presentation.dart';

class DebtCategoryIcon extends StatelessWidget {
  final String id;
  final double size;

  const DebtCategoryIcon({Key? key, required this.id, this.size = 42})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final path = DebtCategoryPresentation.item(id)['image'];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .18),
      decoration: BoxDecoration(
        color: DebtStyle.teal.withOpacity(.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: path == null
          ? Icon(Icons.menu_book_outlined, color: DebtStyle.accent(context))
          : Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.menu_book_outlined,
                color: DebtStyle.accent(context),
              ),
            ),
    );
  }
}
