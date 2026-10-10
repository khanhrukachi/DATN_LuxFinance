import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class GenderWidget extends StatelessWidget {
  const GenderWidget({Key? key, required this.action, required this.gender,
    required this.currentGender}) : super(key: key);
  final bool currentGender;
  final bool gender;
  final Function action;
  @override
  Widget build(BuildContext context) {
    final selected = gender == currentGender;
    return Semantics(selected: selected, button: true,
        child: Material(color: selected ? AuthStyle.accent(context).withOpacity(.12) : AuthStyle.background(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: selected ? AuthStyle.accent(context) : AuthStyle.teal.withOpacity(.2))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: () { action(); },
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Column(children: [
                    Icon(gender ? Icons.male_rounded : Icons.female_rounded, size: 24, color: AuthStyle.accent(context)),
                    const SizedBox(height: 6),
                    Text(AppLocalizations.of(context).translate(gender ? 'male' : 'female'),
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14,
                            color: selected ? AuthStyle.accent(context) : AuthStyle.text(context),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  ]))),
        ));
  }
}
