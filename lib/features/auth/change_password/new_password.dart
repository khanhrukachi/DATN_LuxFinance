import 'package:personal_financial_management/features/auth/widget/auth_style.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_password.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class NewPassword extends StatefulWidget {
  const NewPassword({Key? key}) : super(key: key);

  @override
  State<NewPassword> createState() => _NewPasswordState();
}

class _NewPasswordState extends State<NewPassword> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool hide = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthSurface(child: Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: AuthPanel(child: Column(
          children: [
            const AuthEmblem(icon: Icons.password_rounded),
            Text(
              AppLocalizations.of(context)
                  .translate('enter_your_new_password'),
              textAlign: TextAlign.center,
              style:
              const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              textAlign: TextAlign.center,
              AppLocalizations.of(context)
                  .translate('please_enter_your_new_password'),
              style: TextStyle(fontSize: 14, height: 1.6, color: AuthStyle.muted(context)),
            ),
            const SizedBox(height: 28),
            InputPassword(
              hint: AppLocalizations.of(context).translate('password'),
              controller: _passwordController,
              hide: hide,
              action: () {
                setState(() => hide = !hide);
              },
            ),
            const SizedBox(height: 20),
            InputPassword(
              action: () {
                setState(() {
                  hide = !hide;
                });
              },
              hint:
              AppLocalizations.of(context).translate('confirm_password'),
              controller: _confirmPasswordController,
              password: _passwordController,
              hide: hide,
            ),
            const SizedBox(height: 24),
            customButton(
              action: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    var user = FirebaseAuth.instance.currentUser;

                    user!.updatePassword(_passwordController.text).then((_) {
                      Fluttertoast.showToast(
                        msg: AppLocalizations.of(context)
                            .translate("change_password_successfully"),
                      );
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }).catchError((error) {
                      Fluttertoast.showToast(msg: error.toString());
                    });
                  } catch (_) {}
                  return;
                }
              },
              text: AppLocalizations.of(context).translate('submit'),
            ),
          ],
        ),
        ),
      ),
    ));
  }
}
