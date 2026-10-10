import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_text.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ForgotPage extends StatefulWidget {
  const ForgotPage({Key? key}) : super(key: key);

  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthSurface(child: Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: AuthPanel(child: Column(
          children: [
            const AuthEmblem(icon: Icons.lock_reset_rounded),
            Text(
              AppLocalizations.of(context).translate('forgot_password'),
              style:
              const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              textAlign: TextAlign.center,
              AppLocalizations.of(context).translate('don_worry_it_happens'),
              style: TextStyle(fontSize: 14, height: 1.6, color: AuthStyle.muted(context)),
            ),
            const SizedBox(height: 28),
            InputText(
              hint: "Email",
              validator: 0,
              controller: _emailController,
              inputType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            customButton(
              action: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: _emailController.text.trim());
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/success', (route) => false);
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
