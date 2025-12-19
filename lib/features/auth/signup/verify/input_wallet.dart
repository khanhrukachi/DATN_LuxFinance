import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/on_will_pop.dart';
import 'package:personal_financial_management/features/auth/login/widget/custom_button.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class InputWalletPage extends StatefulWidget {
  const InputWalletPage({Key? key}) : super(key: key);

  @override
  State<InputWalletPage> createState() => _InputWalletPageState();
}

class _InputWalletPageState extends State<InputWalletPage> {
  final TextEditingController _moneyController = TextEditingController();
  DateTime? currentBackPressTime;

  bool _isLoading = false;

  @override
  void dispose() {    _moneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () => onWillPop(
          action: (now) => currentBackPressTime = now,
          currentBackPressTime: currentBackPressTime,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context).translate('enter_the_current_balance'),
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 50),

                TextFormField(
                  controller: _moneyController,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyTextInputFormatter.currency(
                      locale: 'vi',
                      symbol: '₫',
                      decimalDigits: 0,
                    ),
                  ],
                  style: const TextStyle(fontSize: 20),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "1.000.000 ₫",
                    contentPadding: const EdgeInsets.all(20),
                    hintStyle: AppStyles.p,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  )

                ),

                const SizedBox(height: 50),

                customButton(
                  text: "OK",
                  action: () async {
                    if (_isLoading) return;

                    final cleanedText = _moneyController.text
                        .replaceAll(RegExp(r'[^0-9]'), '');
                    final int? money = int.tryParse(cleanedText);

                    if (money == null || money <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context).translate('please_enter_a_valid_amount')),
                        ),
                      );
                      return;
                    }

                    _isLoading = true;
                    loadingAnimation(context);

                    try {
                      final spending = Spending(
                        money: money,
                        type: 0,
                        dateTime: DateTime.now(),
                        note: AppLocalizations.of(context).translate('current_money'),
                        typeName: "current_money",
                      );

                      await SpendingFirebase.addSpending(spending);

                      if (!mounted) return;
                      Navigator.of(context, rootNavigator: true).pop();
                      Navigator.pushReplacementNamed(context, '/main');
                    } catch (e) {
                      Navigator.of(context, rootNavigator: true).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("An error occurred: $e")),
                      );
                    } finally {
                      _isLoading = false;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}