import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Filter;
import 'package:diacritic/diacritic.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/filter.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/analytic/search/widget/filter_page.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'package:personal_financial_management/features/main/home/widget/item_spending_day.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final List<Spending> _all = [];
  final Set<String> _loadedIds = {};
  Filter filter = Filter(chooseIndex: [0, 0, 0], friends: [], colors: []);
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;
  String tr(String key) => AppLocalizations.of(context).translate(key);
  String normalize(String value) => removeDiacritics(value).toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ').trim();
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);

  @override
  void initState() { super.initState(); unawaited(_load()); }
  @override
  void dispose() { _debounce?.cancel(); _searchController.dispose(); super.dispose(); }

  Future<void> _load({bool clear = false}) async {
    final generation = ++_generation;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    bool current() => mounted && generation == _generation && FirebaseAuth.instance.currentUser?.uid == uid;
    setState(() {
      _loading = true; _failed = false;
      if (clear) { _all.clear(); _loadedIds.clear(); }
    });
    try {
      if (uid == null) throw StateError('No session');
      final index = await FirebaseFirestore.instance.collection('data').doc(uid)
          .get().timeout(const Duration(seconds: 20));
      if (!current()) return;
      final ids = <String>{};
      for (final value in (index.data() ?? <String, dynamic>{}).values) {
        if (value is List) {
          for (final id in value) {
            if (id is String && id.isNotEmpty && !id.contains('/') && !_loadedIds.contains(id)) ids.add(id);
          }
        }
      }
      final pending = ids.toList().reversed.toList();
      for (int offset = 0; offset < pending.length; offset += 6) {
        if (!current()) return;
        final chunk = pending.skip(offset).take(6).toList();
        final results = await Future.wait(chunk.map((id) async {
          try {
            final doc = await FirebaseFirestore.instance.collection('spending').doc(id)
                .get().timeout(const Duration(seconds: 20));
            return _SearchResult(id, doc.exists ? Spending.fromFirebase(doc) : null);
          } catch (_) { return _SearchResult(id, null, failed: true); }
        }));
        if (!current()) return;
        setState(() {
          for (final result in results) {
            if (result.failed) { _failed = true; continue; }
            _loadedIds.add(result.id);
            if (result.item != null) _all.add(result.item!);
          }
          _all.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        });
      }
    } catch (_) {
      if (current()) setState(() => _failed = true);
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  bool _notEqual(String key) {
    final value = normalize(key);
    return value.contains('not') || value.contains('different') ||
        value.contains('unequal') || value.contains('khong');
  }

  bool _matches(Spending spending) {
    final config = spending.type >= 0 && spending.type < listType.length ? listType[spending.type] : null;
    final title = config?['title'] ?? '';
    final amount = spending.money.abs();
    final searchable = normalize([
      title, title.isEmpty ? '' : tr(title), spending.typeName ?? '',
      spending.note ?? '', spending.location ?? '', ...(spending.friends ?? <String>[]),
      amount.toString(), if (amount % 1000 == 0) '${amount ~/ 1000}k',
      '${spending.dateTime.day}/${spending.dateTime.month}/${spending.dateTime.year}',
    ].join(' '));
    final words = normalize(_query).split(' ').where((word) => word.isNotEmpty);
    if (!words.every(searchable.contains)) return false;

    final moneyMode = filter.chooseIndex[0];
    if (moneyMode == 1 && amount < filter.money) return false;
    if (moneyMode == 2 && amount > filter.money) return false;
    if (moneyMode == 3) {
      final min = filter.money < filter.finishMoney ? filter.money : filter.finishMoney;
      final max = filter.money > filter.finishMoney ? filter.money : filter.finishMoney;
      if (amount < min || amount > max) return false;
    }
    if (moneyMode == 4) {
      final equal = amount == filter.money;
      if (_notEqual(moneyList[4]) ? equal : !equal) return false;
    }
    final date = day(spending.dateTime);
    final start = filter.time == null ? null : day(filter.time!);
    final finish = filter.finishTime == null ? null : day(filter.finishTime!);
    final timeMode = filter.chooseIndex[1];
    if (timeMode == 1 && start != null && date.isBefore(start)) return false;
    if (timeMode == 2 && start != null && date.isAfter(start)) return false;
    if (timeMode == 3 && start != null && finish != null) {
      final min = start.isBefore(finish) ? start : finish;
      final max = start.isBefore(finish) ? finish : start;
      if (date.isBefore(min) || date.isAfter(max)) return false;
    }
    if (timeMode == 4 && start != null) {
      final equal = date == start;
      if (_notEqual(timeList[4]) ? equal : !equal) return false;
    }
    if (filter.chooseIndex[2] == 1 && spending.money < 0) return false;
    if (filter.chooseIndex[2] == 2 && spending.money > 0) return false;
    final friends = filter.friends ?? <String>[];
    final transactionFriends = (spending.friends ?? <String>[]).map(normalize).toSet();
    if (friends.isNotEmpty && !friends.any((friend) => transactionFriends.contains(normalize(friend)))) return false;
    if (!normalize(spending.note ?? '').contains(normalize(filter.note))) return false;
    return true;
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _all.where(_matches).toList();
    return ProfileSurface(child: Scaffold(
      appBar: AppBar(titleSpacing: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
          title: TextField(controller: _searchController, onChanged: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) { _debounce?.cancel(); setState(() => _query = value); },
              decoration: ProfileStyle.input(context, tr('search'), icon: Icons.search_rounded,
                  suffix: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () {
                    _debounce?.cancel(); _searchController.clear(); setState(() => _query = '');
                  })).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
          actions: [IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FilterPage(filter: filter,
                action: (value) {
                  if (mounted) setState(() { filter = value.copyWith(); _query = _searchController.text; });
                })));
          })]),
      body: Column(children: [
        if (_loading) LinearProgressIndicator(color: ProfileStyle.accent(context), minHeight: 3),
        if (_loading) Padding(padding: const EdgeInsets.all(8), child: Text(tr('search_loading_partial'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ProfileStyle.muted(context)))),
        if (_failed && !_loading) Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [Expanded(child: Text(tr('profile_load_error'), style: const TextStyle(fontSize: 12))),
              TextButton(onPressed: () { unawaited(_load()); }, child: Text(tr('search_retry')))])),
        Expanded(child: result.isEmpty
            ? _loading ? const Center(child: CircularProgressIndicator())
            : ProfileEmpty(icon: Icons.search_off_rounded, text: tr('nothing_here'))
            : ItemSpendingDay(spendingList: result)),
      ]),
    ));
  }
}

class _SearchResult {
  const _SearchResult(this.id, this.item, {this.failed = false});
  final String id;
  final Spending? item;
  final bool failed;
}
