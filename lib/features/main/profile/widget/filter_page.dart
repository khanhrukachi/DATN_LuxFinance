import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/pick_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/spending/add_spending/add_friend_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/filter.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({
    Key? key,
    required this.action,
    required this.filter,
  }) : super(key: key);

  final Function(Filter filter) action;
  final Filter filter;

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final NumberFormat currencyFormatter =
  NumberFormat.currency(locale: 'vi_VI', symbol: '');

  final TextEditingController moneyController = TextEditingController();
  final TextEditingController finishMoneyController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  late Filter filter;
  late DateTimeRange range;

  @override
  void initState() {
    super.initState();
    filter = widget.filter.copyWith();
    noteController.text = filter.note;
    moneyController.text =
    filter.money == 0 ? '' : currencyFormatter.format(filter.money);
    finishMoneyController.text = filter.finishMoney == 0
        ? ''
        : currencyFormatter.format(filter.finishMoney);

    range = DateTimeRange(
      start: filter.time ?? DateTime.now(),
      end: filter.finishTime ?? DateTime.now(),
    );
  }

  @override
  void dispose() {
    moneyController.dispose();
    finishMoneyController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('filter')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _applyFilter,
            child: Text(
              AppLocalizations.of(context).translate('search'),
              style: const TextStyle(fontSize: 16),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            icon: Icons.payments_rounded,
            title: AppLocalizations.of(context).translate('money'),
            value: _moneyValue(),
            onTap: _showMoneyPicker,
          ),
          _tile(
            icon: Icons.calendar_today_rounded,
            title: AppLocalizations.of(context).translate('time'),
            value: _timeValue(),
            onTap: pickDateRange,
          ),
          _tile(
            icon: Icons.group_rounded,
            title: AppLocalizations.of(context).translate('friend'),
            value: filter.friends!.isEmpty
                ? AppLocalizations.of(context).translate('all')
                : '${filter.friends!.length} người',
            onTap: _pickFriend,
          ),
          _tile(
            icon: Icons.sticky_note_2_rounded,
            title: AppLocalizations.of(context).translate('note'),
            value: filter.note.isEmpty
                ? AppLocalizations.of(context).translate('all')
                : filter.note,
            onTap: _inputNote,
          ),
          _tile(
            icon: Icons.swap_vert_rounded,
            title: AppLocalizations.of(context).translate('group'),
            value: AppLocalizations.of(context)
                .translate(groupList[filter.chooseIndex[2]]),
            onTap: _showGroupPicker,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Text(value, style: TextStyle(color: Colors.grey.shade600)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  void _showMoneyPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView.builder(
        itemCount: moneyList.length,
        itemBuilder: (_, index) => ListTile(
          title:
          Text(AppLocalizations.of(context).translate(moneyList[index])),
          onTap: () async {
            Navigator.pop(context);
            await _inputMoney(index);
          },
        ),
      ),
    );
  }

  Future _inputMoney(int index) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:
        Text(AppLocalizations.of(context).translate('enter_amount')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: moneyController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyTextInputFormatter(currencyFormatter),
              ],
              decoration:
              const InputDecoration(hintText: 'Từ'),
            ),
            if (index == 3) ...[
              const SizedBox(height: 12),
              TextField(
                controller: finishMoneyController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyTextInputFormatter(currencyFormatter),
                ],
                decoration:
                const InputDecoration(hintText: 'Đến'),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => filter.chooseIndex[0] = index);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  String _moneyValue() {
    if (filter.chooseIndex[0] == 0) {
      return AppLocalizations.of(context).translate(moneyList[0]);
    }
    if (filter.chooseIndex[0] == 3) {
      return '${moneyController.text} - ${finishMoneyController.text}';
    }
    return moneyController.text;
  }

  String _timeValue() {
    if (filter.chooseIndex[1] == 0) {
      return AppLocalizations.of(context).translate(timeList[0]);
    }
    if (filter.chooseIndex[1] == 3) {
      return '${DateFormat('dd/MM/yyyy').format(filter.time!)} - '
          '${DateFormat('dd/MM/yyyy').format(filter.finishTime!)}';
    }
    return DateFormat('dd/MM/yyyy').format(filter.time!);
  }

  Future pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      initialDateRange: range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      setState(() {
        range = result;
        filter.chooseIndex[1] = 3;
        filter.time = result.start;
        filter.finishTime = result.end;
      });
    }
  }

  Future _inputNote() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('note')),
        content: TextField(
          controller: noteController,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _pickFriend() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFriendPage(
          friends: filter.friends!,
          colors: filter.colors!,
          action: (friends, colors) {
            setState(() {
              filter.friends = List.from(friends);
              filter.colors = List.from(colors);
            });
          },
        ),
      ),
    );
  }

  void _showGroupPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView.builder(
        itemCount: groupList.length,
        itemBuilder: (_, index) => ListTile(
          title: Text(
            AppLocalizations.of(context).translate(groupList[index]),
          ),
          onTap: () {
            setState(() => filter.chooseIndex[2] = index);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _applyFilter() {
    widget.action(
      filter.copyWith(
        money: _parseMoney(moneyController.text),
        finishMoney: _parseMoney(finishMoneyController.text),
        note: noteController.text,
      ),
    );
    Navigator.pop(context);
  }

  int _parseMoney(String text) {
    if (text.isEmpty) return 0;
    return int.parse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }
}
