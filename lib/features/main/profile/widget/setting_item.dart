import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';

Widget settingItem({required String text, required Function action,
  required IconData icon, Color? color}) => ProfileRow(title: text, icon: icon,
    color: color, onTap: () { action(); });
