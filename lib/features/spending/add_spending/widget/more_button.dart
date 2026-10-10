import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
class MoreButton extends StatelessWidget {
  const MoreButton({Key? key, required this.action, required this.more}) : super(key: key);
  final Function action;
  final bool more;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => action(),
    style: TextButton.styleFrom(foregroundColor: SpendingStyle.accent(context),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(AppLocalizations.of(context).translate(more ? 'hide_away' : 'more_details'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      Icon(more ? Icons.expand_less_rounded : Icons.expand_more_rounded),
    ]),
  );
}
