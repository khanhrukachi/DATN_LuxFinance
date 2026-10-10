import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';

class BeautifulTab extends StatelessWidget {
  const BeautifulTab({Key? key, required this.icon, required this.textVi,
    required this.textEn}) : super(key: key);
  final IconData icon;
  final String textVi;
  final String textEn;
  @override
  Widget build(BuildContext context) => Tab(height: 44,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18), const SizedBox(width: 6),
            Flexible(child: Text(Localizations.localeOf(context).languageCode == 'vi' ? textVi : textEn,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ])));
}

// Retains the original private name for code in the same Dart library.
class _BeautifulTab extends BeautifulTab {
  const _BeautifulTab({required IconData icon, required String textVi, required String textEn})
      : super(icon: icon, textVi: textVi, textEn: textEn);
}
