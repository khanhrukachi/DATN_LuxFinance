import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_helpers.dart';
import 'package:personal_financial_management/features/main/debt/add/new_debt_contact_dialog.dart';
import 'debt_action_button.dart';
import 'debt_contact_avatar.dart';

class DebtContactPicker extends StatefulWidget {
  final DebtFirebase service;
  final String? selectedId;

  const DebtContactPicker({Key? key, required this.service, this.selectedId})
    : super(key: key);

  @override
  State<DebtContactPicker> createState() => _DebtContactPickerState();
}

class _DebtContactPickerState extends State<DebtContactPicker> {
  late final Stream<List<DebtContact>> stream;
  final search = TextEditingController();
  bool adding = false;

  @override
  void initState() {
    super.initState();
    stream = widget.service.watchContacts();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> add() async {
    if (adding) return;
    FocusScope.of(context).unfocus();
    setState(() => adding = true);
    try {
      final contact = await showDialog<DebtContact>(
        context: context,
        builder: (_) => NewDebtContactDialog(service: widget.service),
      );
      if (contact != null && mounted) Navigator.pop(context, contact);
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DebtStyle.muted(context).withOpacity(.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtTranslate(context, 'debt_picker_title'),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          debtTranslate(context, 'debt_picker_subtitle'),
                          style: TextStyle(
                            fontSize: 12,
                            color: DebtStyle.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: debtTranslate(context, 'common_close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: DebtStyle.input(
                  context,
                  debtTranslate(context, 'debt_picker_search'),
                  icon: Icons.search_rounded,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: DebtActionButton(
                label: debtTranslate(context, 'debt_picker_add'),
                icon: Icons.person_add_alt_1_rounded,
                onPressed: adding ? null : add,
              ),
            ),
          ],
        ),
      ),
      StreamBuilder<List<DebtContact>>(
        stream: stream,
        builder: (context, s) {
          if (s.hasError) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    debtTranslate(context, 'debt_picker_load_error') +
                        ': ' +
                        s.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (!s.hasData) {
            return SliverToBoxAdapter(
              child: Shimmer.fromColors(
                baseColor: DebtStyle.card(context),
                highlightColor: DebtStyle.teal.withOpacity(.18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        Container(
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }
          final keyword = search.text.trim().toLowerCase();
          final list = s.data!
              .where(
                (c) => '${c.name} ${c.phone}'.toLowerCase().contains(keyword),
              )
              .toList();
          if (list.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 40,
                        color: DebtStyle.accent(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        keyword.isEmpty
                            ? debtTranslate(context, 'debt_picker_empty')
                            : debtTranslate(context, 'debt_picker_no_results'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final c = list[index];
                final selected = c.id == widget.selectedId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? DebtStyle.teal.withOpacity(.12)
                        : DebtStyle.background(context),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      leading: DebtContactAvatar(name: c.name),
                      title: Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        c.phone.isEmpty
                            ? debtTranslate(context, 'debt_no_phone')
                            : c.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: DebtStyle.accent(context),
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: DebtStyle.muted(context),
                            ),
                      onTap: () => Navigator.pop(context, c),
                    ),
                  ),
                );
              }, childCount: list.length),
            ),
          );
        },
      ),
    ],
  );
}
