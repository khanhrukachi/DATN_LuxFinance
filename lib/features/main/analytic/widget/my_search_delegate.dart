import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';

class MySearchDelegate extends SearchDelegate<String> {
  String q;
  bool check = true;
  String text;

  MySearchDelegate({required this.text, required this.q}) {
    query = q;
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    TextButton(
      onPressed: () {
        close(context, query);
      },
      child: Text(text, style: TextStyle(color: AnalyticStyle.accent(context), fontWeight: FontWeight.w600)),
    )
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () {
      close(context, q);
    },
    icon: Icon(Icons.arrow_back_rounded, color: AnalyticStyle.accent(context)),
  );

  @override
  Widget buildResults(BuildContext context) {
    return Container();
  }

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    scaffoldBackgroundColor: AnalyticStyle.background(context),
    appBarTheme: Theme.of(context).appBarTheme.copyWith(
        backgroundColor: AnalyticStyle.background(context), elevation: 0,
        iconTheme: IconThemeData(color: AnalyticStyle.accent(context))),
    inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none, hintStyle: TextStyle(color: AnalyticStyle.muted(context))),
  );

  @override
  Widget buildSuggestions(BuildContext context) {
    if (check) { query = q; check = false; }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('history').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data();
        if (data == null) return const SizedBox.shrink();
        final history = (data['history'] is List ? data['history'] as List : const [])
            .map((e) => e.toString()).where((e) => e.toUpperCase().contains(query.toUpperCase()))
            .toList().reversed.toList();
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => Material(color: AnalyticStyle.card(context),
              borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: () { query = history[i]; showResults(context); },
                child: Padding(padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    child: Row(children: [
                      Icon(Icons.history_rounded, size: 20, color: AnalyticStyle.accent(context)),
                      const SizedBox(width: 12), Expanded(child: Text(history[i], style: const TextStyle(fontSize: 15))),
                      IconButton(onPressed: () => query = history[i],
                          icon: Icon(Icons.north_west_rounded, size: 19, color: AnalyticStyle.muted(context))),
                    ])),
              )),
        );
      },
    );
  }

  @override
  void showResults(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { close(context, query); return; }
    if (query.isNotEmpty) {
      var firestore = FirebaseFirestore.instance
          .collection("history")
          .doc(user.uid);

      firestore.get().then((value) {
        var data = {};
        if (value.data() != null) {
          data = value.data() as Map<String, dynamic>;
        }
        List<String> history = [];
        if (data["history"] != null) {
          history = (data["history"] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        }
        history.remove(query);
        history.add(query);
        if (value.data() == null) {
          firestore.set({"history": history});
        } else {
          firestore.update({"history": history});
        }
      });
      close(context, query);
    }
  }

  @override
  String? get searchFieldLabel => text;

  @override
  TextStyle? get searchFieldStyle =>
      const TextStyle(fontSize: 18);
}
