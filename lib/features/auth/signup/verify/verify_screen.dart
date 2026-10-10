import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/auth/signup/verify/update_profile_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({Key? key}) : super(key: key);

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  bool isEmailVerify = false;
  bool canResendEmail = false;
  Timer? timer;
  DateTime? currentBackPressTime;

  @override
  void initState() {
    super.initState();
    isEmailVerify = FirebaseAuth.instance.currentUser!.emailVerified;
    if (!isEmailVerify) {
      sendVerificationEmail();
      timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        checkEmailVerified();
      });
    }
  }

  Future checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser!.reload();
    if (!mounted) return;
    setState(() {
      isEmailVerify = FirebaseAuth.instance.currentUser!.emailVerified;
    });

    if (isEmailVerify) {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    if (timer != null) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future sendVerificationEmail() async {
    if (mounted) setState(() => canResendEmail = false);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user!.sendEmailVerification();
      if (!mounted) return;
      setState(() => canResendEmail = false);
      await Future<void>.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => canResendEmail = true);
    } catch (_) {
      if (mounted) setState(() => canResendEmail = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return AuthSurface(child: Scaffold(
      body: WillPopScope(
        onWillPop: () => onWillPop(action: (now) => currentBackPressTime = now,
            currentBackPressTime: currentBackPressTime),
        child: SafeArea(child: AuthPanel(child: Column(children: [
          AuthEmblem(icon: isEmailVerify ? Icons.verified_user_outlined : Icons.mark_email_unread_outlined),
          Text(tr.translate('verify_email'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, color: AuthStyle.text(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(tr.translate(isEmailVerify ? 'congratulation_your_email_verified'
              : 'please_check_your_email_verify_your_email'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6, color: AuthStyle.muted(context))),
          const SizedBox(height: 28),
          if (isEmailVerify)
            AuthButton(text: tr.translate('go_to_home'), icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.of(context).pushReplacement(
                    createRoute(screen: const UpdateProfileScreen())))
          else ...[
            AuthButton(text: tr.translate('resend_email'), icon: Icons.mail_outline_rounded,
                onPressed: canResendEmail ? () { sendVerificationEmail(); } : null),
            const SizedBox(height: 12),
            TextButton(onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }, child: Text(tr.translate('cancel'))),
          ],
        ]))),
      ),
    ));
  }
}
