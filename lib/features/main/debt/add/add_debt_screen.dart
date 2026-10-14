import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import '../widget/debt_editor.dart';

class AddDebtScreen extends StatelessWidget {
  final DebtFirebase service;

  const AddDebtScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) => DebtEditor(service: service);
}
