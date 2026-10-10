import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/item_spending_day.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const int _pageSize = 24;
  static const int _parallelReads = 6;
  final List<Spending> _items = [];
  final Set<String> _loadedIds = {};
  final Set<String> _failedIds = {};
  List<String> _ids = [];
  String? _uid;
  int _cursor = 0;
  int _generation = 0;
  bool _loadingIndex = true;
  bool _loadingMore = false;
  bool _indexFailed = false;
  bool get _hasMore => _cursor < _ids.length;
  String tr(String key) => AppLocalizations.of(context).translate(key);

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  bool _isCurrent(int generation, String? uid) => mounted &&
      generation == _generation && FirebaseAuth.instance.currentUser?.uid == uid;

  Future<void> _refresh() async {
    final generation = ++_generation;
    _uid = FirebaseAuth.instance.currentUser?.uid;
    final uid = _uid;
    setState(() {
      _items.clear(); _loadedIds.clear(); _failedIds.clear(); _ids = [];
      _cursor = 0; _loadingIndex = true; _loadingMore = false; _indexFailed = false;
    });
    if (uid == null) {
      if (mounted) setState(() { _loadingIndex = false; _indexFailed = true; });
      return;
    }
    try {
      // Reuse the user's existing index; no new owner field or Firestore index required.
      final snapshot = await FirebaseFirestore.instance.collection('data').doc(uid)
          .get().timeout(const Duration(seconds: 20));
      if (!_isCurrent(generation, uid)) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      final keys = data.keys.toList()..sort((a, b) => _monthKey(b).compareTo(_monthKey(a)));
      final unique = <String>{};
      for (final key in keys) {
        final value = data[key];
        if (value is! List) continue;
        for (final id in value.reversed) {
          if (id is String && id.isNotEmpty && !id.contains('/')) unique.add(id);
        }
      }
      setState(() { _ids = unique.toList(); _loadingIndex = false; });
      await _loadMore();
    } catch (_) {
      if (!_isCurrent(generation, uid)) return;
      setState(() { _loadingIndex = false; _indexFailed = true; });
    }
  }

  int _monthKey(String key) {
    final match = RegExp(r'^(\d{1,2})_(\d{4})$').firstMatch(key);
    if (match == null) return 0;
    return int.parse(match.group(2)!) * 100 + int.parse(match.group(1)!);
  }

  Future<void> _loadMore({bool retry = false}) async {
    if (_loadingIndex || _loadingMore || _indexFailed || _uid == null) return;
    final pending = retry ? _failedIds.toList() : _ids.skip(_cursor).take(_pageSize).toList();
    if (pending.isEmpty) return;
    final generation = _generation;
    final uid = _uid;
    setState(() => _loadingMore = true);
    try {
      // Publish each small batch immediately instead of waiting for the entire page.
      for (int offset = 0; offset < pending.length; offset += _parallelReads) {
        if (!_isCurrent(generation, uid)) return;
        final chunk = pending.skip(offset).take(_parallelReads).toList();
        final results = await Future.wait(chunk.map((id) async {
          try {
            final doc = await FirebaseFirestore.instance.collection('spending').doc(id)
                .get().timeout(const Duration(seconds: 20));
            return _HistoryResult(id, doc.exists ? Spending.fromFirebase(doc) : null);
          } catch (_) {
            return _HistoryResult(id, null, failed: true);
          }
        }));
        if (!_isCurrent(generation, uid)) return;
        setState(() {
          for (final result in results) {
            if (result.failed) { _failedIds.add(result.id); continue; }
            _failedIds.remove(result.id);
            if (result.item != null && _loadedIds.add(result.id)) _items.add(result.item!);
          }
          if (!retry) _cursor += chunk.length;
          _items.sort((a, b) {
            final dateOrder = b.dateTime.compareTo(a.dateTime);
            return dateOrder != 0 ? dateOrder : a.id.toString().compareTo(b.id.toString());
          });
        });
      }
    } finally {
      if (_isCurrent(generation, uid)) setState(() => _loadingMore = false);
    }
  }

  void _nearEnd(ScrollMetrics metrics) {
    if (metrics.axis == Axis.vertical && metrics.extentAfter < 300 &&
        _hasMore && _failedIds.isEmpty && !_loadingMore && !_loadingIndex) {
      // Defer state changes until after layout notifications have completed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadMore());
      });
    }
  }

  @override
  Widget build(BuildContext context) => ProfileSurface(child: Scaffold(
    appBar: AppBar(title: Text(tr('history')), centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context)),
        actions: [IconButton(tooltip: tr('history_refresh'), icon: const Icon(Icons.refresh_rounded),
            onPressed: () { unawaited(_refresh()); })]),
    body: Column(children: [
      if (_items.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(tr('history_partial_hint'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.4, color: ProfileStyle.muted(context)))),
      Expanded(child: _loadingIndex ? _skeleton() : _indexFailed
          ? _error()
          : _items.isEmpty && _loadingMore ? _skeleton()
          : _items.isEmpty ? _empty()
          : NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) { _nearEnd(notification.metrics); return false; },
          child: NotificationListener<ScrollNotification>(
              onNotification: (notification) { _nearEnd(notification.metrics); return false; },
              child: RefreshIndicator(onRefresh: _refresh, color: ProfileStyle.accent(context),
                  child: ItemSpendingDay(key: ValueKey<int>(_generation), spendingList: _items))))),
      if (!_loadingIndex && !_indexFailed) _footer(),
    ]),
  ));

  Widget _footer() => SafeArea(top: false, child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: _loadingMore ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2,
          color: ProfileStyle.accent(context))), const SizedBox(width: 10),
      Flexible(child: Text(tr('history_loading_more'), style: TextStyle(fontSize: 12,
          color: ProfileStyle.muted(context)))),
    ]) : _failedIds.isNotEmpty ? Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tr('history_page_error'), textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: ProfileStyle.muted(context))),
      TextButton.icon(onPressed: () { unawaited(_loadMore(retry: true)); },
          icon: const Icon(Icons.refresh_rounded), label: Text(tr('history_retry'))),
    ]) : _hasMore ? TextButton.icon(onPressed: () { unawaited(_loadMore()); },
        icon: const Icon(Icons.expand_more_rounded), label: Text(tr('history_load_more')))
        : _items.isEmpty ? const SizedBox.shrink()
        : Text(tr('history_all_loaded'), textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: ProfileStyle.muted(context))),
  ));

  Widget _error() => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_outlined, size: 40, color: ProfileStyle.accent(context)),
        const SizedBox(height: 12), Text(tr('profile_load_error'), textAlign: TextAlign.center,
            style: TextStyle(color: ProfileStyle.muted(context))),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () { unawaited(_refresh()); },
            icon: const Icon(Icons.refresh_rounded), label: Text(tr('history_retry'))),
      ])));

  Widget _empty() => RefreshIndicator(onRefresh: _refresh,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        SizedBox(height: MediaQuery.of(context).size.height * .45,
            child: ProfileEmpty(icon: Icons.receipt_long_outlined, text: tr('nothing_here'))),
      ]));

  Widget _skeleton() => Shimmer.fromColors(baseColor: ProfileStyle.card(context),
      highlightColor: ProfileStyle.teal.withOpacity(.15),
      child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => Container(height: 92, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)))));
}

class _HistoryResult {
  const _HistoryResult(this.id, this.item, {this.failed = false});
  final String id;
  final Spending? item;
  final bool failed;
}
