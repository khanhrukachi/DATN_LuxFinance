import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final int currentLanguage;
  final Function(int) onLanguageChanged;

  const LanguageSelector({
    Key? key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20),
      width: double.infinity,
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => onLanguageChanged(0),
            child: Row(
              children: [
                Image.asset("assets/images/vietnam.png", width: 70),
                const Spacer(),
                const Text(
                  "Tiếng Việt",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Radio(
                  value: 0,
                  groupValue: currentLanguage,
                  onChanged: (value) => onLanguageChanged(0),
                )
              ],
            ),
          ),
          InkWell(
            onTap: () => onLanguageChanged(1),
            child: Row(
              children: [
                Image.asset("assets/images/english.png", width: 70),
                const Spacer(),
                const Text(
                  "English",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Radio(
                  value: 1,
                  groupValue: currentLanguage,
                  onChanged: (value) => onLanguageChanged(1),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
