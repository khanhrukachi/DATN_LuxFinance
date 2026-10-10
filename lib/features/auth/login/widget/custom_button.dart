import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/auth/widget/auth_style.dart';

Widget customButton({required String text, required Function action}) =>
    AuthButton(text: text, onPressed: () { action(); });
