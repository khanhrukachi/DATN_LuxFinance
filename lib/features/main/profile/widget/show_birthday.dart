import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'package:intl/intl.dart';

Widget showBirthday(DateTime date) => Builder(builder: (context) => Ink(
  decoration: BoxDecoration(color: ProfileStyle.background(context),
      borderRadius: BorderRadius.circular(16), border: Border.all(color: ProfileStyle.teal.withOpacity(.2))),
  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(children: [Icon(Icons.calendar_month_outlined, color: ProfileStyle.accent(context), size: 20),
        const SizedBox(width: 12), Expanded(child: Text(DateFormat('dd/MM/yyyy').format(date),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ProfileStyle.text(context)))),
        Icon(Icons.expand_more_rounded, color: ProfileStyle.accent(context))])),
));
