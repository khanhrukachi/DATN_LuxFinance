import 'dart:io';

import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/pick_function.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/add_friend.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/input_money.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/input_spending.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/item_spending.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/more_button.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/pick_image_widget.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/remove_icon.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';

import 'choose_type.dart';

class AddSpendingPage extends StatefulWidget {
  const AddSpendingPage({Key? key}) : super(key: key);

  @override
  State<AddSpendingPage> createState() => _AddSpendingPageState();
}

class _AddSpendingPageState extends State<AddSpendingPage> {
  final _money = TextEditingController();
  final _note = TextEditingController();
  final _location = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  int? type;
  XFile? image;
  bool more = false;
  String? typeName;
  String? categoryId;
  String? parentId;
  String? parentName;
  int coefficient = 1;
  List<String> friends = [];
  List<Color> colors = [];

  @override
  void dispose() {
    _money.dispose();
    _note.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SpendingStyle.background(context),
        title: Text(AppLocalizations.of(context).translate('add_spending')),
        centerTitle: false,
        actions: [
          SpendingSaveAction(
            label: AppLocalizations.of(context).translate('save'),
            onPressed: () async { await addingSpending(); },
          )
        ],
        leading: IconButton(
          icon: const Icon(Icons.close_outlined, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: InputMoney(controller: _money),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            addSpending(),
            if (more) moreFunction(),
            MoreButton(
              action: () => setState(() => more = !more),
              more: more,
            ),
            const SizedBox(height: 10)
          ],
        ),
      ),
    );
  }

  Widget addSpending() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: SpendingStyle.card(context),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: SpendingStyle.teal.withOpacity(.16)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset(
                    type == null
                        ? "assets/icons/question_mark.png"
                        : (listType[type!]["image"] ??
                        "assets/icons/question_mark.png"),
                    width: 35,
                    errorBuilder: (_, __, ___) => Icon(Icons.category_outlined, color: SpendingStyle.accent(context), size: 35),
                  ),
                  Expanded(
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        Navigator.of(context).push(
                          createRoute(
                            screen: ChooseType(
                              action: (index, coefficient, name, selectedItem) {
                                setState(() {
                                  type = index;
                                  typeName = name;
                                  categoryId = selectedItem['id'];
                                  parentId = selectedItem['parent'];
                                  parentName = selectedItem['parentName'];
                                  this.coefficient = coefficient;
                                });
                              },
                            ),
                            begin: const Offset(1, 0),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            type == null
                                ? AppLocalizations.of(context).translate('type')
                                : (categoryId == "custom"
                                ? typeName!
                                : AppLocalizations.of(context)
                                .translate(listType[type!]["title"]!)),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          )),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, color: SpendingStyle.accent(context)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              line(),
              itemSpending(
                color: SpendingStyle.accent(context),
                icon: Icons.calendar_month_rounded,
                text: DateFormat("dd/MM/yyyy").format(selectedDate),
                action: () async {
                  var day = await selectDate(
                      context: context, initialDate: selectedDate);
                  if (mounted && day != null && day != selectedDate) {
                    setState(() => selectedDate = day);
                  }
                },
              ),
              line(),
              itemSpending(
                color: SpendingStyle.accent(context),
                icon: Icons.access_time_rounded,
                text:
                "${selectedTime.hour.toString().padLeft(2, "0")}:${selectedTime.minute.toString().padLeft(2, "0")}",
                action: () async {
                  var time = await selectTime(
                      context: context, initialTime: selectedTime);
                  if (mounted && time != null && time != selectedTime) {
                    setState(() => selectedTime = time);
                  }
                },
              ),
              line(),
              inputSpending(
                icon: Icons.edit_note_rounded,
                color: SpendingStyle.accent(context),
                controller: _note,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                hintText: AppLocalizations.of(context).translate('note'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget moreFunction() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: SpendingStyle.card(context),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: SpendingStyle.teal.withOpacity(.16)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  inputSpending(
                    icon: Icons.location_on_outlined,
                    color: SpendingStyle.accent(context),
                    controller: _location,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    hintText:
                    AppLocalizations.of(context).translate('location'),
                  ),
                  line(),
                  const SizedBox(height: 5),
                  AddFriend(
                    friends: friends,
                    colors: colors,
                    add: (friends, colors) {
                      setState(() {
                        this.colors = colors;
                        this.friends = friends;
                      });
                    },
                    remove: (index) => setState(() {
                      friends.removeAt(index);
                      colors.removeAt(index);
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          imageWidget(),
        ],
      ),
    );
  }

  Widget imageWidget() {
    return Card(
      color: SpendingStyle.card(context),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: SpendingStyle.teal.withOpacity(.16)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: image == null
          ? pickImageWidget(image: (file) {
        if (mounted && file != null) {
          setState(() => image = file);
        }
      })
          : Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Image.file(
              File(image!.path),
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: removeIcon(
              background: SpendingStyle.danger.withOpacity(0.9),
              color: Colors.white,
              action: () => setState(() => image = null),
            ),
          )
        ],
      ),
    );
  }

  Widget line() {
    return Divider(
      color: SpendingStyle.teal.withOpacity(.12),
      thickness: 0.5,
      endIndent: 10,
      indent: 10,
    );
  }

  Future addingSpending() async {
    String moneyString = _money.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (type != null &&
        moneyString.isNotEmpty &&
        moneyString.compareTo("0") != 0) {
      int money = int.parse(moneyString);

      String typeName = '';
      final selected = listType[type!];
      if (type! >= 0 && type! < listType.length) {
        typeName = selected['title'] ?? '';
      }

      Spending spending = Spending(
        money: categoryId == "custom"
            ? coefficient * money
            : coefficient * money,
        type: type!,
        typeName: typeName.trim(),
        categoryId: categoryId ?? selected['id'],
        parentId: parentId ?? selected['parent'],
        parentName: parentName,
        dateTime: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        ),
        note: _note.text.trim(),
        image: image != null ? image!.path : null,
        location: _location.text.trim(),
        friends: friends,
      );

      loadingAnimation(context);
      await SpendingFirebase.addSpending(spending);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
    } else if (type == null) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context).translate('please_select_type'));
    } else {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context).translate('please_enter_valid_amount'),
      );
    }
  }
}
