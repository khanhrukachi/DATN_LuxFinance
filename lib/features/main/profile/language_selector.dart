import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key, required this.currentLanguage,
    required this.onLanguageChanged}) : super(key: key);
  final int currentLanguage;
  final Function(int) onLanguageChanged;
  @override
  Widget build(BuildContext context) => SafeArea(top: false,
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: ProfileStyle.muted(context).withOpacity(.3),
                  borderRadius: BorderRadius.circular(4))),
          for (final index in [0, 1]) ...[
            Material(color: index == currentLanguage ? ProfileStyle.accent(context).withOpacity(.1) : ProfileStyle.card(context),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: index == currentLanguage ? ProfileStyle.accent(context) : ProfileStyle.teal.withOpacity(.16))),
                child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.asset(
                        index == 0 ? 'assets/images/vietnam.png' : 'assets/images/english.png', width: 38)),
                    title: Text(index == 0 ? 'Tiếng Việt' : 'English', style: TextStyle(fontSize: 14,
                        color: ProfileStyle.text(context), fontWeight: FontWeight.w600)),
                    trailing: Icon(index == currentLanguage ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: index == currentLanguage ? ProfileStyle.accent(context) : ProfileStyle.muted(context), size: 22),
                    onTap: () => onLanguageChanged(index))),
            if (index == 0) const SizedBox(height: 10),
          ],
        ])),
  );
}
