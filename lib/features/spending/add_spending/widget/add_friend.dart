import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_friend_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/circle_text.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/remove_icon.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
class AddFriend extends StatelessWidget {
  const AddFriend({Key? key, required this.friends, required this.colors,
    required this.add, required this.remove}) : super(key: key);
  final List<String> friends;
  final List<Color> colors;
  final Function(List<String> friends, List<Color> colors) add;
  final Function(int index) remove;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent,
    borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () {
      Navigator.of(context).push(createRoute(screen: AddFriendPage(friends: friends,
          colors: colors, action: (f, c) => add(f, c)), begin: const Offset(1, 0)));
    }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const SpendingFieldIcon(icon: Icons.people_outline_rounded),
          const SizedBox(width: 12),
          Expanded(child: friends.isEmpty
              ? Text(AppLocalizations.of(context).translate('friend'),
              style: TextStyle(fontSize: 15, color: SpendingStyle.muted(context)))
              : Wrap(spacing: 8, runSpacing: 8, children: List.generate(friends.length, (i) => Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: SpendingStyle.teal.withOpacity(.08),
                borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              circleText(text: friends[i].isEmpty ? '?' : friends[i].substring(0, 1),
                  color: i < colors.length ? colors[i] : SpendingStyle.teal),
              const SizedBox(width: 8),
              Flexible(child: Text(friends[i], style: const TextStyle(fontSize: 14))),
              const SizedBox(width: 4), removeIcon(action: () => remove(i)),
            ]),
          )))),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: SpendingStyle.muted(context)),
        ])),
    ),
  );
}
