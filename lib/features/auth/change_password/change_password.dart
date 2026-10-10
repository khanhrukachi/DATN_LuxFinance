import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_password.dart';
import 'package:personal_financial_management/features/auth/change_password/new_password.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({Key? key}) : super(key: key);

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool hide = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reauthenticateAndProceed() async {
    if (!_formKey.currentState!.validate()) return;

    loadingAnimation(context); // show loading
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'no-user');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      if (!mounted) return;
      Navigator.pop(context); // remove loading dialog
      Navigator.of(context).push(createRoute(
        screen: const NewPassword(),
        begin: const Offset(1, 0),
      ));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // remove loading dialog

      String msg = "";
      if (e.code == 'wrong-password') {
        msg = AppLocalizations.of(context).translate("incorrect_password");
      } else if (e.code == 'no-user') {
        msg = AppLocalizations.of(context).translate("user_not_found");
      } else {
        msg = AppLocalizations.of(context).translate("unknown_error_login");
      }

      Fluttertoast.showToast(msg: msg);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate("unknown_error_login"),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthSurface(child: Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: AuthPanel(child: Column(
          children: [
            const AuthEmblem(icon: Icons.lock_outline_rounded),
            const SizedBox(height: 15),
            Text(
              AppLocalizations.of(context)
                  .translate('you_want_change_your_password'),
              textAlign: TextAlign.center,
              style:
              const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)
                  .translate('please_enter_your_current_password'),
              textAlign: TextAlign.center,
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
            const SizedBox(height: 24),
            customButton(
              action: _reauthenticateAndProceed,
              text: AppLocalizations.of(context).translate('submit'),
            ),
          ],
        ),
        ),
      ),
    ));
  }
}
