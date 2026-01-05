import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/pick_function.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/spending/add_spending/choose_type.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/add_friend.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/input_money.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/input_spending.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/item_spending.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/more_button.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/pick_image_widget.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/remove_icon.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:shimmer/shimmer.dart';

class EditSpendingPage extends StatefulWidget {
  const EditSpendingPage({
    Key? key,
    required this.spending,
    this.change,
  }) : super(key: key);

  final Spending spending;
  final Function(Spending spending, List<Color> colors)? change;

  @override
  State<EditSpendingPage> createState() => _EditSpendingPageState();
}

class _EditSpendingPageState extends State<EditSpendingPage> {
  final _money = TextEditingController();
  final _note = TextEditingController();
  final _location = TextEditingController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  int? type;
  String? typeName;
  int coefficient = 1;

  XFile? image;
  bool checkPickImage = false;
  bool more = false;

  List<String> friends = [];
  List<Color> colors = [];

  @override
  void initState() {
    super.initState();

    _money.text = NumberFormat.currency(locale: "vi_VI")
        .format(widget.spending.money.abs());

    _note.text = widget.spending.note ?? '';
    _location.text = widget.spending.location ?? '';

    selectedDate = widget.spending.dateTime;
    selectedTime = TimeOfDay(
      hour: widget.spending.dateTime.hour,
      minute: widget.spending.dateTime.minute,
    );

    type = widget.spending.type;
    typeName = widget.spending.typeName;
    coefficient = widget.spending.money < 0 ? -1 : 1;

    friends = List<String>.from(widget.spending.friends);
    colors = friends
        .map(
          (_) => Color.fromRGBO(
        Random().nextInt(255),
        Random().nextInt(255),
        Random().nextInt(255),
        1,
      ),
    )
        .toList();
  }

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.background,
        title: Text(AppLocalizations.of(context).translate('edit_spending')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_outlined),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: updateSpending,
            child: Text(
              AppLocalizations.of(context).translate('save'),
              style: AppStyles.p,
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: InputMoney(controller: _money),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildMainCard(),
            if (more) buildMore(),
            MoreButton(
              more: more,
              action: () => setState(() => more = !more),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ================= UI =================

  Widget buildMainCard() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              itemSpending(
                icon: Icons.calendar_month,
                color: Colors.orange,
                text: DateFormat("dd/MM/yyyy").format(selectedDate),
                action: () async {
                  final day = await selectDate(
                    context: context,
                    initialDate: selectedDate,
                  );
                  if (day != null) setState(() => selectedDate = day);
                },
              ),
              line(),
              itemSpending(
                icon: Icons.access_time,
                color: Colors.amber,
                text:
                "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                action: () async {
                  final time = await selectTime(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) setState(() => selectedTime = time);
                },
              ),
              line(),
              inputSpending(
                icon: Icons.edit_note,
                color: Colors.deepOrange,
                controller: _note,
                hintText:
                AppLocalizations.of(context).translate('note'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMore() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AddFriend(
                friends: friends,
                colors: colors,
                add: (f, c) => setState(() {
                  friends = f;
                  colors = c;
                }),
                remove: (i) => setState(() {
                  friends.removeAt(i);
                  colors.removeAt(i);
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          buildImage(),
        ],
      ),
    );
  }

  Widget buildImage() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: image == null && (widget.spending.image == null || checkPickImage)
          ? pickImageWidget(
        image: (file) => setState(() => image = file),
      )
          : showImage(),
    );
  }

  Widget showImage() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: image != null
              ? Image.file(File(image!.path))
              : CachedNetworkImage(imageUrl: widget.spending.image!),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: removeIcon(
            action: () => setState(() => checkPickImage = true),
          ),
        ),
      ],
    );
  }

  Widget line() => const Divider(thickness: 0.5);

  Future<void> updateSpending() async {
    final moneyRaw = _money.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (moneyRaw.isEmpty) return;

    final money = int.parse(moneyRaw);
    final signedMoney = coefficient * money;

    final newSpending = Spending(
      id: widget.spending.id,
      money: signedMoney,
      type: type!,
      typeName: typeName,
      dateTime: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ),
      note: _note.text.trim(),
      image: widget.spending.image,
      location: _location.text.trim(),
      friends: friends,
    );

    loadingAnimation(context);

    await SpendingFirebase.updateSpending(
      newSpending,
      widget.spending.dateTime,
      image != null ? File(image!.path) : null,
      checkPickImage,
    );

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context);
    Navigator.pop(context);
    Navigator.pop(context);
  }
}
