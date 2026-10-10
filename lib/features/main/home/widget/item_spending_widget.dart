import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';
import 'package:shimmer/shimmer.dart';

import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ItemSpendingWidget extends StatelessWidget {
  const ItemSpendingWidget({Key? key, this.spendingList, this.embedded = false}) : super(key: key);
  final List<Spending>? spendingList;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return spendingList != null
        ? ListView.builder(
      shrinkWrap: embedded, physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: listType.length,
      itemBuilder: (context, index) {
        if ([0, 10, 21, 27, 35, 38].contains(index)) {
          return const SizedBox.shrink();
        }

        final list =
        spendingList!.where((e) => e.type == index).toList();
        if (list.isEmpty) return const SizedBox.shrink();

        return _item(context, index, list);
      },
    )
        : _loading(context);
  }

  // ================= ITEM =================

  Widget _item(BuildContext context, int index, List<Spending> list) => HomeCategoryTile(
    title: AppLocalizations.of(context).translate(listType[index]['title'] ?? 'other'),
    image: listType[index]['image'], money: list.fold<int>(0, (s, e) => s + e.money),
    onTap: () => Navigator.of(context).push(createRoute(
        screen: ViewListSpendingPage(spendingList: list), begin: const Offset(1, 0))),
  );

  Widget _loading(BuildContext context) => HomeLoadingList(embedded: embedded);

  Widget textLoading(int width, {int height = 16,
    required Color baseShimmer, required Color highlightShimmer}) => Shimmer.fromColors(
    baseColor: baseShimmer, highlightColor: highlightShimmer,
    child: Container(width: width.toDouble(), height: height.toDouble(), color: baseShimmer),
  );
}

Widget textLoading(int width, {int height = 16}) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      height: height.toDouble(),
      width: width.toDouble(),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}
