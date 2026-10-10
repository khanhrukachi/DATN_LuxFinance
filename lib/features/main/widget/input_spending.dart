import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/function/list_categories.dart';
import 'package:personal_financial_management/features/main/widget/transaction_input_form.dart';

class InputSpending extends StatelessWidget {
  const InputSpending({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => TransactionInputForm(expense: true, categories: categories);
}
