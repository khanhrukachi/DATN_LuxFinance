import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/auth/login/login_page.dart';
import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_password.dart';
import 'package:personal_financial_management/features/auth/login/widget/input_text.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/auth/signup/bloc/signup_bloc.dart';
import 'package:personal_financial_management/features/auth/signup/bloc/signup_event.dart';
import 'package:personal_financial_management/features/auth/signup/bloc/singup_state.dart';
import 'package:personal_financial_management/features/auth/signup/gender_widget.dart';
import 'package:personal_financial_management/features/auth/signup/verify/verify_screen.dart';
import 'package:personal_financial_management/models/user.dart';


class SignupForm extends StatefulWidget {
  const SignupForm({Key? key}) : super(key: key);

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime birthday = DateTime.now();
  bool hide = true;
  bool gender = true;
  bool check = true;

  @override
  void dispose() {
    _nameController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SignupBloc, SignupState>(
      builder: (context, state) {
        if (state is SignupSuccessState && check) {
          Navigator.pop(context);
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context)
                  .translate("create-account-success"));
          SchedulerBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 3), () {
              Navigator.of(context).pushReplacement(
                createRoute(screen: const VerifyPage()),
              );
            });
          });
        }

        if (state is SignupErrorState && check) {
          Navigator.pop(context);
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context).translate(state.status));
        }
        check = true;

        return Form(
          key: _formKey,
          child: AuthPanel(child: Column(
            children: [
              const AuthEmblem(icon: Icons.person_add_alt_1_rounded),
              Text(
                AppLocalizations.of(context).translate('hello_new_user'),
                style: const TextStyle(
                    fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).translate('welcome_to_app'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: AuthStyle.muted(context)),
              ),
              const SizedBox(height: 28),
              InputText(
                hint: AppLocalizations.of(context).translate('full_name'),
                validator: 1,
                controller: _nameController,
                inputType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              InputText(
                hint: "Email",
                validator: 0,
                controller: _userController,
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GenderWidget(currentGender: gender, gender: true,
                    action: () { check = false; setState(() => gender = true); })),
                const SizedBox(width: 12),
                Expanded(child: GenderWidget(currentGender: gender, gender: false,
                    action: () { check = false; setState(() => gender = false); })),
              ]),
              const SizedBox(height: 20),
              Material(color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        builder: (_, child) => AuthSurface(child: child!),
                        initialDate: birthday,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && picked != birthday) {
                        check = false;
                        setState(() => birthday = picked);
                      }
                    },
                    child: Ink(
                      padding: const EdgeInsets.only(right: 10, left: 20),
                      width: double.infinity,
                      height: 57,
                      decoration: BoxDecoration(
                        color: AuthStyle.background(context),
                        border: Border.all(color: AuthStyle.teal.withOpacity(.2)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            DateFormat("dd/MM/yyyy").format(birthday),
                            style: TextStyle(fontSize: 14, color: AuthStyle.text(context)),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 22,
                            color: AuthStyle.accent(context),
                          )
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 20),
              InputPassword(
                action: () {
                  check = false;
                  setState(() => hide = !hide);
                },
                hint: AppLocalizations.of(context).translate('password'),
                controller: _passwordController,
                hide: hide,
              ),
              const SizedBox(height: 20),
              InputPassword(
                action: () {
                  check = false;
                  setState(() => hide = !hide);
                },
                hint: AppLocalizations.of(context)
                    .translate('confirm_password'),
                controller: _confirmPasswordController,
                password: _passwordController,
                hide: hide,
              ),
              const SizedBox(height: 20),
              customButton(
                action: () {
                  if (_formKey.currentState!.validate()) {
                    loadingAnimation(context);
                    BlocProvider.of<SignupBloc>(context).add(
                      SignupEmailPasswordEvent(
                        email: _userController.text.trim(),
                        password: _passwordController.text,
                        user: User(
                          name: _nameController.text.trim(),
                          money: 0,
                          birthday:
                          DateFormat("dd/MM/yyyy").format(birthday),
                          gender: gender,
                          avatar: "",
                        ),
                      ),
                    );
                    return;
                  }
                },
                text: AppLocalizations.of(context).translate('sign_up'),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('have_account'),
                    style: TextStyle(fontSize: 14, color: AuthStyle.text(context)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        createRoute(screen: const LoginPage()),
                      );
                    },
                    child: Text(
                      AppLocalizations.of(context).translate('login_now'),
                      style: TextStyle(fontSize: 14, color: AuthStyle.text(context)),
                    ),
                  )
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
