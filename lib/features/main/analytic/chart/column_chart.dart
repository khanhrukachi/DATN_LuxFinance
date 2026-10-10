import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
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

class ColumnChartState extends State<ColumnChart>
    with SingleTickerProviderStateMixin {
  final Duration animDuration = const Duration(milliseconds: 500);
  int touchedIndex = -1;
  double max = 0;
  List<int> money = [];
  List<String> weekOfMonth = [];

  final List<Color> paletteColors = AnalyticStyle.palette;

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

    final chartMax = max * 1.3;
    final width = widget.index == 0 ? 520.0 : 1000.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: width,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AnalyticStyle.background(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AnalyticStyle.teal.withOpacity(.12),
              ),
            ),
            child: BarChart(
              mainBarData(chartMax),
              swapAnimationDuration: animDuration,
            ),
          ),
        ),
      ),
    );
  }

  int maxValue(int a, int b) => a > b ? a : b;

  BarChartGroupData makeGroupData(
      int x,
      double y,
      double chartMax, {
        bool isTouched = false,
      }) {
    final color = AnalyticStyle.teal;

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(10)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AnalyticStyle.cyan.withOpacity(isTouched ? 1 : .8),
              color.withOpacity(isTouched ? 1 : .8),
            ],
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: chartMax,
            color: AnalyticStyle.teal.withOpacity(.08),
          ),
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
          (i) => makeGroupData(
        i,
        money[i].toDouble(),
        chartMax,
        isTouched: i == touchedIndex,
      ),
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
              "${AppLocalizations.of(context).translate('week')} ${group.x + 1}";
            } else {
              label = AppLocalizations.of(context)
                  .translate(listMonthOfYear[group.x.toInt()]);
            }

            return BarTooltipItem(
              "$label\n${AnalyticStyle.money(context, rod.toY)}",
              const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        touchCallback: (event, response) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                response?.spot == null) {
              touchedIndex = -1;
              return;
            }
            touchedIndex = response!.spot!.touchedBarGroupIndex;
          });
        },
      ),
      titlesData: FlTitlesData(
        rightTitles:
        AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
        AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            reservedSize: 36,
            getTitlesWidget: bottomTitles,
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: chartMax / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AnalyticStyle.teal.withOpacity(.08),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: showingGroups(chartMax),
      backgroundColor: Colors.transparent,
    );
  }

  Widget leftTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        "${(value / 1000).toStringAsFixed(0)}K",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AnalyticStyle.muted(context),
        ),
      ),
    );
  }

  Widget bottomTitles(double value, TitleMeta meta) {
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
      space: 14,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
