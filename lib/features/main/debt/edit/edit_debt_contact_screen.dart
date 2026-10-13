import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import '../widget/debt_contact_form.dart';

class EditDebtContactScreen extends StatelessWidget {
  final DebtFirebase service;
  final DebtContact contact;

  const EditDebtContactScreen({
    super.key,
    required this.service,
    required this.contact,
  });

  @override
  Widget build(BuildContext context) =>
      DebtContactEditor(service: service, contact: contact);
}
