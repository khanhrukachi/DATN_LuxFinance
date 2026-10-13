import 'package:flutter/material.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

String debtTranslate(BuildContext context, String key) =>
    AppLocalizations.of(context).translate(key);

String debtMoney(int n) =>
    '${NumberFormat.decimalPattern('vi_VN').format(n)} ₫';

String debtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

String debtStatus(BuildContext context, Debt d) => d.remaining == 0
    ? debtTranslate(context, 'debt_status_paid')
    : d.overdue
    ? debtTranslate(context, 'debt_status_overdue')
    : d.paid > 0
    ? debtTranslate(context, 'debt_status_partial')
    : debtTranslate(context, 'debt_status_unpaid');

String roleName(BuildContext context, String role) => debtTranslate(
  context,
  {
        'person': 'debt_role_person',
        'customer': 'debt_role_customer',
        'supplier': 'debt_role_supplier',
        'lender': 'debt_role_lender',
        'borrower': 'debt_role_borrower',
      }[role] ??
      'debt_role_person',
);
