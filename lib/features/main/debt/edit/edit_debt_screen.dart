import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import '../widget/debt_form.dart';

class EditDebtScreen extends StatelessWidget {
  final DebtFirebase service;
  final Debt debt;

  const EditDebtScreen({super.key, required this.service, required this.debt});

  @override
  Widget build(BuildContext context) =>
      DebtEditor(service: service, debt: debt);
}
