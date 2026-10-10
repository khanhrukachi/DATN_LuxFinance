import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/circle_text.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/remove_icon.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({
    Key? key,
    required this.friends,
    required this.action,
    required this.colors,
  }) : super(key: key);
  final List<String> friends;
  final Function(List<String> friends, List<Color> colors) action;
  final List<Color> colors;

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _friend = TextEditingController();
  List<String> friends = [];
  final List<Color> colors = [];

  @override
  void initState() {
    friends.addAll(widget.friends);
    colors.addAll(List.generate(widget.friends.length, (i) =>
    i < widget.colors.length ? widget.colors[i] : SpendingStyle.teal));
    super.initState();
  }

  @override
  void dispose() { _friend.dispose(); super.dispose(); }

  void _addFriend() {
    final name = _friend.text.trim();
    if (name.isEmpty) return;
    setState(() { friends.add(name); colors.add(SpendingStyle.teal); _friend.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(elevation: 0, backgroundColor: SpendingStyle.background(context),
        centerTitle: false, title: Text(tr.translate('add_friends')),
        actions: [SpendingSaveAction(label: tr.translate('done'), onPressed: () {
          widget.action(friends, colors); Navigator.pop(context);
        })],
      ),
      body: Padding(padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextFormField(controller: _friend, textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _addFriend(),
            cursorColor: SpendingStyle.accent(context),
            decoration: SpendingStyle.input(context, tr.translate('add_friends'),
                icon: Icons.person_add_alt_1_rounded).copyWith(
                suffixIcon: IconButton(icon: Icon(Icons.add_rounded, color: SpendingStyle.accent(context)),
                    onPressed: _addFriend)),
          ),
          const SizedBox(height: 16),
          Expanded(child: ListView.separated(itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => Container(
              padding: const EdgeInsets.all(12), decoration: SpendingStyle.decoration(context),
              child: Row(children: [
                circleText(text: friends[i].isEmpty ? '?' : friends[i].substring(0, 1),
                    color: colors[i]),
                const SizedBox(width: 12),
                Expanded(child: Text(friends[i], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                const SizedBox(width: 8),
                removeIcon(action: () => setState(() { friends.removeAt(i); colors.removeAt(i); })),
              ]),
            ),
          )),
        ]),
      ),
    );
  }
}
