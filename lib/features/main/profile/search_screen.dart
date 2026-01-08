import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/core/constants/function/extension.dart';
import 'package:personal_financial_management/models/filter.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/analytic/widget/filter_page.dart';
import 'package:personal_financial_management/features/main/analytic/widget/my_search_delegate.dart';
import 'package:personal_financial_management/features/main/home/widget/item_spending_day.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:diacritic/diacritic.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String? query;

  Filter filter = Filter(chooseIndex: [0, 0, 0], friends: [], colors: []);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String normalizeText(String text) =>
      removeDiacritics(text).toLowerCase();

  bool checkResult(Spending spending) {
    if (query != null &&
        query!.isNotEmpty &&
        !normalizeText(
          AppLocalizations.of(context)
              .translate(listType[spending.type]["title"]!),
        ).contains(normalizeText(query!))) {
      return false;
    }

    if (filter.chooseIndex[0] == 1 && spending.money.abs() < filter.money) {
      return false;
    } else if (filter.chooseIndex[0] == 2 &&
        spending.money.abs() > filter.money) {
      return false;
    } else if (filter.chooseIndex[0] == 3 &&
        (spending.money.abs() > filter.finishMoney ||
            spending.money.abs() < filter.money)) {
      return false;
    } else if (filter.chooseIndex[0] == 4 &&
        spending.money.abs() == filter.money) {
      return false;
    }

    if (filter.chooseIndex[1] == 1 &&
        filter.time!.isAfter(spending.dateTime.formatToDate())) {
      return false;
    } else if (filter.chooseIndex[1] == 2 &&
        filter.time!.isBefore(spending.dateTime.formatToDate())) {
      return false;
    } else if (filter.chooseIndex[1] == 3 &&
        (spending.dateTime.formatToDate().isAfter(filter.finishTime!) ||
            spending.dateTime.formatToDate().isBefore(filter.time!))) {
      return false;
    } else if (filter.chooseIndex[1] == 4 &&
        isSameDay(spending.dateTime, filter.time)) {
      return false;
    }

    if (filter.chooseIndex[2] == 1 && spending.money < 0) return false;
    if (filter.chooseIndex[2] == 2 && spending.money > 0) return false;

    if (filter.friends!.isNotEmpty) {
      final list = filter.friends!
          .where((e) => spending.friends!.contains(e))
          .toList();
      if (list.isEmpty) return false;
    }

    if (spending.note != null && !spending.note!.contains(filter.note)) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
              )
            ],
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              icon: const Icon(Icons.search_rounded),
              hintText:
              AppLocalizations.of(context).translate('search'),
              border: InputBorder.none,
            ),
            onTap: () async {
              query = await showSearch(
                context: context,
                delegate: MySearchDelegate(
                  text: AppLocalizations.of(context).translate('search'),
                  q: _searchController.text,
                ),
              );
              if (query != null) {
                setState(() => _searchController.text = query!);
              }
            },
            onSubmitted: (value) {
              setState(() => query = value.trim());
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.of(context).push(
                createRoute(
                  screen: FilterPage(
                    filter: filter,
                    action: (f) =>
                        setState(() => filter = f.copyWith()),
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: query == null || query!.isEmpty
            ? _emptySearch(context)
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _resultBody(context),
        ),
      ),
    );
  }

  Widget _resultBody(BuildContext context) {
    return FutureBuilder(
      future: firestore.FirebaseFirestore.instance
          .collection("data")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data =
        snapshot.requireData.data() as Map<String, dynamic>;
        final ids = <String>[];

        for (var e in data.entries) {
          ids.addAll((e.value as List).map((e) => e.toString()));
        }

        return FutureBuilder(
          future: SpendingFirebase.getSpendingList(ids),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final list =
            snapshot.data!.where(checkResult).toList();

            if (list.isEmpty) {
              return _noResult(context);
            }

            return ItemSpendingDay(spendingList: list);
          },
        );
      },
    );
  }

  Widget _emptySearch(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).translate('search'),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResult(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).translate('nothing_here'),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
