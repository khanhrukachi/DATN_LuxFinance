import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import '../widget/debt_contact_form.dart';

class AddDebtContactScreen extends StatelessWidget {
  final DebtFirebase service;

  const AddDebtContactScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) => DebtContactEditor(service: service);
}
