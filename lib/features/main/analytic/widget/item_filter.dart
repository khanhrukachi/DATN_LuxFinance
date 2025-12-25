import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:flutter/material.dart';

class ItemFilter extends StatelessWidget {
  const ItemFilter({
    Key? key,
    required this.text,
    required this.action,
    required this.list,
    required this.value,
    this.content,
  }) : super(key: key);

  final String text;
  final Function(int) action;
  final List<String> list;
  final String value;
  final String? content;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(12), // ✅ bo giống card
                border: Border.all(
                  color: Colors.black12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  isExpanded: true,
                  hint: Center(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  items: list.map((e) {
                    return DropdownMenuItem<String>(
                      value: e,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).translate(e),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      action(list.indexOf(value));
                    }
                  },
                  iconStyleData: const IconStyleData(
                    icon: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
