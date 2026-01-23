import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/auth/forgot/forgot_screen.dart';
import 'package:personal_financial_management/features/auth/login/bloc/login_bloc.dart';
import 'package:personal_financial_management/features/auth/login/bloc/login_event.dart';
import 'package:personal_financial_management/features/auth/login/bloc/login_state.dart';
import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_password.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_text.dart';
import 'package:personal_financial_management/features/auth/login/widget/text_continue.dart';
import 'package:personal_financial_management/models/api_service.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/auth/signup/signup_page.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool hide = true;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccessState) {
          Navigator.pop(context);

          final uid = FirebaseAuth.instance.currentUser!.uid;
          debugPrint("🔥 USER ID = $uid");

          unawaited(APIService.fetchAI(uid));

          Fluttertoast.showToast(
            msg: AppLocalizations.of(context).translate("login_success"),
          );

          if (state.social == Social.email &&
              !FirebaseAuth.instance.currentUser!.emailVerified) {
            Navigator.pushReplacementNamed(context, "/verify");
          } else if (state.social == Social.newUser) {
            Navigator.pushReplacementNamed(context, "/survey");
          } else {
            Navigator.pushReplacementNamed(context, "/main");
          }
        }

        if (state is LoginErrorState) {
          Navigator.pop(context);
          Fluttertoast.showToast(
            msg: AppLocalizations.of(context)
                .translate('unknown_error_login'),
          );
        }
      },
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context).translate('hello_again'),
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)
                    .translate('welcome_back_you_been_missed'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 50),

              InputText(
                hint: "Email",
                validator: 0,
                controller: _userController,
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              InputPassword(
                action: () => setState(() => hide = !hide),
                hint: AppLocalizations.of(context).translate('password'),
                controller: _passwordController,
                hide: hide,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        createRoute(
                          screen: const ForgotPage(),
                          begin: const Offset(1, 0),
                        ),
                      );
                    },
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('forgot_password'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              customButton(
                action: () {
                  if (_formKey.currentState!.validate()) {
                    loadingAnimation(context);
                    context.read<LoginBloc>().add(
                      LoginWithEmailPasswordEvent(
                        email: _userController.text.trim(),
                        password: _passwordController.text.trim(),
                      ),
                    );
                  }
                },
                text: AppLocalizations.of(context).translate('sign_in'),
              ),

              const SizedBox(height: 30),
              const TextContinue(),
              const SizedBox(height: 20),

              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    loadingAnimation(context);
                    context.read<LoginBloc>().add(LoginWithGoogleEvent());
                  },
                  icon: Image.asset(
                    "assets/logo/google_logo.png",
                    width: 20,
                  ),
                  label: const Text(
                    "Google",
                    style: TextStyle(color: Color.fromRGBO(125, 125, 125, 1)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)
                        .translate('do_not_have_account'),
                    style: AppStyles.p,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        createRoute(screen: const SignupPage()),
                      );
                    },
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('register_now'),
                      style: AppStyles.p,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
