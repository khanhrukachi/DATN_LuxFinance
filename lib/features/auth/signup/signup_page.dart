import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/features/auth/signup/bloc/signup_bloc.dart';
import 'package:personal_financial_management/features/auth/signup/signup_form.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () => onWillPop(
          action: (now) => currentBackPressTime = now,
          currentBackPressTime: currentBackPressTime,
        ),
        child: SafeArea(
          child: BlocProvider(
            create: (context) => SignupBloc(),
            child: const SignupForm(),
          ),
        ),
      ),
    );
  }
}
