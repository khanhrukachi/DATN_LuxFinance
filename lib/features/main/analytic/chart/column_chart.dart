import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/main/analytic/function/render_list_money.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';

class ColumnChart extends StatefulWidget {
  const ColumnChart({
    Key? key,
    required this.index,
    required this.list,
    required this.dateTime,
  }) : super(key: key);

  final int index;
  final List<Spending> list;
  final DateTime dateTime;

  @override
  State<StatefulWidget> createState() => ColumnChartState();
}

class ColumnChartState extends State<ColumnChart> with SingleTickerProviderStateMixin {
  final Duration animDuration = const Duration(milliseconds: 500);
  int touchedIndex = -1;
  double max = 0;
  List<int> money = [];
  List<String> weekOfMonth = [];

  final List<Color> paletteColors = [
    Color(0xff4e79a7),
    Color(0xfff28e2b),
    Color(0xffe15759),
    Color(0xff76b7b2),
    Color(0xff59a14f),
    Color(0xffff9da7),
    Color(0xff9c755f),
    Color(0xffbab0ac),
    Color(0xffedc948),
  ];

  @override
  Widget build(BuildContext context) {
    money = renderListMoney(
      index: widget.index,
      list: widget.list,
      dateTime: widget.dateTime,
      getList: (list) => weekOfMonth = list,
    );

    if (money.isNotEmpty) {
      max = money.reduce(maxValue).toDouble();
      if (max == 0) max = 1000;
    } else {
      max = 1000;
    }

    double chartMax = max * 1.3;

    double width = widget.index == 0 ? 500 : 1000;

    return AspectRatio(
      aspectRatio: 1.2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.green.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: BarChart(
            mainBarData(chartMax),
            swapAnimationDuration: animDuration,
          ),
        ),
      ),
    );
  }

  int maxValue(int a, int b) => a > b ? a : b;

  BarChartGroupData makeGroupData(int x, double y, double chartMax, {bool isTouched = false}) {
    final color = paletteColors[x % paletteColors.length];

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 20,
          gradient: LinearGradient(
            colors: [
              color.withOpacity(isTouched ? 0.9 : 0.6),
              color.withOpacity(isTouched ? 1.0 : 0.8),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: chartMax, // dùng chartMax thay vì max
            color: Colors.grey.shade300.withOpacity(0.3),
          ),
          rodStackItems: [],
        ),
      ],
      showingTooltipIndicators: isTouched ? [0] : [],
    );
  }

  List<BarChartGroupData> showingGroups(double chartMax) {
    int column = 7;
    if (widget.index == 1) column = money.length;
    if (widget.index == 2) column = 12;

    return List.generate(
      column,
          (i) => makeGroupData(i, money[i].toDouble(), chartMax, isTouched: i == touchedIndex),
    );
  }

  BarChartData mainBarData(double chartMax) {
    return BarChartData(
      maxY: chartMax,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            String label = "";
            if (widget.index == 0) {
              label = AppLocalizations.of(context)
                  .translate(listDayOfWeek[group.x.toInt()]);
            } else if (widget.index == 1) {
              label =
              "${AppLocalizations.of(context).translate('week')} ${group.x.toInt() + 1}";
            } else {
              label = AppLocalizations.of(context)
                  .translate(listMonthOfYear[group.x.toInt()]);
            }

            return BarTooltipItem(
              '$label\n💰 ${(rod.toY).toStringAsFixed(0)}',
              const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        touchCallback: (event, response) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.spot == null) {
              touchedIndex = -1;
              return;
            }
            touchedIndex = response.spot!.touchedBarGroupIndex;
          });
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
            reservedSize: 50, // padding trên 50px
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: leftTitles,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            getTitlesWidget: bottomTitles,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: showingGroups(chartMax),
      gridData: FlGridData(show: true),
      backgroundColor: Colors.transparent,
    );
  }

  Widget leftTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff7589a2),
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text("${(value / 1000).toStringAsFixed(0)}K", style: style),
    );
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.black87,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String title = "";
    if (widget.index == 0) {
      title = AppLocalizations.of(context)
          .translate(listDayOfWeekAcronym[value.toInt()]);
    } else if (widget.index == 1) {
      title = weekOfMonth[value.toInt()];
    } else {
      title = AppLocalizations.of(context)
          .translate(listMonthOfYearAcronym[value.toInt()]);
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16,
      child: Text(title, style: style),
    );
  }
}
