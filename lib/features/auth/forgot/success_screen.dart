import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class SuccessPage extends StatefulWidget {
  const SuccessPage({Key? key}) : super(key: key);

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    return AuthSurface(child: Scaffold(
      body: WillPopScope(
        onWillPop: () => onWillPop(
          action: (now) => currentBackPressTime = now,
          currentBackPressTime: currentBackPressTime,
        ),
        child: SafeArea(
          child: AuthPanel(child: Column(
            children: [
              const AuthEmblem(icon: Icons.mark_email_read_outlined),
              Text(
                AppLocalizations.of(context).translate('success'),
                style: const TextStyle(
                  fontSize: 23,

                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                textAlign: TextAlign.center,
                AppLocalizations.of(context)
                    .translate('check_your_email_make_password_change'),
                style: TextStyle(fontSize: 14, height: 1.6, color: AuthStyle.muted(context)),
              ),
              const SizedBox(height: 28),
              customButton(
                text: AppLocalizations.of(context).translate('go_to_login'),
                action: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              )
            ],
          ),
          ),
        ),
      ),
    ));
  }
}
