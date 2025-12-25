import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/bloc/setting_cubit.dart';
import 'package:personal_financial_management/setting/bloc/setting_state.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/view_spending/view_spending_page.dart';
import 'package:table_calendar/table_calendar.dart';

class ItemSpendingDay extends StatefulWidget {
  const ItemSpendingDay({Key? key, required this.spendingList}) : super(key: key);
  final List<Spending> spendingList;

  @override
  State<ItemSpendingDay> createState() => _ItemSpendingDayState();
}

class _ItemSpendingDayState extends State<ItemSpendingDay> {
  final NumberFormat numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  Widget build(BuildContext context) {
    widget.spendingList.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final dates = widget.spendingList
        .map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day))
        .toSet()
        .toList();

    if (dates.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).translate('no_data'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return BlocBuilder<SettingCubit, SettingState>(
      builder: (_, settingState) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];

            final list = widget.spendingList
                .where((e) => isSameDay(e.dateTime, date))
                .toList();

            final total = list.fold<int>(0, (sum, e) => sum + e.money);

            return _dayCard(date, total, list, settingState.locale.languageCode);
          },
        );
      },
    );
  }

  Widget _dayCard(DateTime date, int total, List<Spending> list, String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Color(0xFF1C1C1C);
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final accent = total >= 0 ? Color(0xFF2FBF71) : Color(0xFFE5533D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _dateCircle(date, accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.EEEE(lang).format(date),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        Text(
                          DateFormat.yMMMM(lang).format(date),
                          style: TextStyle(fontSize: 14, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    numberFormat.format(total),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Items
            ...list.map(_itemRow).toList(),
          ],
        ),
      ),
    );
  }

  Widget _dateCircle(DateTime date, Color accent) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.35), accent.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          DateFormat("dd").format(date),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent),
        ),
      ),
    );
  }

  Widget _itemRow(Spending spending) {
    final typeConfig = listType[spending.type];
    final imagePath = typeConfig?["image"];
    final titleKey = typeConfig?["title"];

    return InkWell(
      onTap: () => _onTapItem(spending),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            imagePath != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(imagePath, width: 40, height: 40, fit: BoxFit.cover),
            )
                : Icon(Icons.money_rounded, size: 40, color: Colors.grey.shade500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                spending.type == 41
                    ? (spending.typeName ?? '')
                    : AppLocalizations.of(context).translate(titleKey ?? ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              numberFormat.format(spending.money),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: spending.money < 0 ? Color(0xFFE5533D) : Color(0xFF2FBF71),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTapItem(Spending spending) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewSpendingPage(
          spending: spending,
          change: (updated) async {
            try {
              updated.image = await FirebaseStorage.instance
                  .ref("spending/${updated.id}.png")
                  .getDownloadURL();
            } catch (_) {}

            if (!mounted) return;
            setState(() {
              widget.spendingList.removeWhere((e) => e.id == updated.id);
              widget.spendingList.add(updated);
            });
          },
          delete: (id) {
            if (!mounted) return;
            setState(() {
              widget.spendingList.removeWhere((e) => e.id == id);
            });
          },
        ),
      ),
    );
  }
}
