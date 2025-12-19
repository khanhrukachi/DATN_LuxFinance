import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/spending.dart';

class MyPieChart extends StatefulWidget {
  const MyPieChart({Key? key, required this.list}) : super(key: key);
  final List<Spending> list;

  @override
  State<MyPieChart> createState() => _MyPieChartState();
}

class _MyPieChartState extends State<MyPieChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  int sum = 1;
  late AnimationController _controller;

  // Palette màu hài hòa
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
  void initState() {
    super.initState();

    // Animation PieChart
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.list.isNotEmpty) {
      sum = widget.list
          .map((e) => e.money.abs())
          .reduce((value, element) => value + element);
    }

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse
                        .touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 6,
              centerSpaceRadius: 40,
              sections: showingSections(_controller.value),
            ),
          );
        },
      ),
    );
  }

  List<PieChartSectionData> showingSections(double progress) {
    List<PieChartSectionData> pieChartList = [];

    for (int i = 0; i < listType.length; i++) {
      if (![0, 10, 21, 27, 35, 38].contains(i)) {
        List<Spending> spendingList =
        widget.list.where((element) => element.type == i).toList();
        if (spendingList.isNotEmpty) {
          final isTouched = pieChartList.length == touchedIndex;
          final fontSize = isTouched ? 20.0 : 16.0;
          final radius = isTouched ? 110.0 : 100.0;
          final widgetSize = isTouched ? 55.0 : 40.0;

          int sumSpending = spendingList
              .map((e) => e.money.abs())
              .reduce((value, element) => value + element);

          double value = (sumSpending / sum) * 100 * progress;

          // Lấy màu từ palette, vòng lại nếu vượt quá số màu
          final color = paletteColors[i % paletteColors.length];

          pieChartList.add(
            PieChartSectionData(
              color: color,
              value: value,
              title: isTouched
                  ? "${listType[i]["name"]}\n${value.toStringAsFixed(1)}%"
                  : "",
              radius: radius,
              titleStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.6),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              badgeWidget: _Badge(
                listType[i]["image"]!,
                size: widgetSize,
                borderColor: Colors.white,
                isTouched: isTouched,
              ),
              badgePositionPercentageOffset: 0.98,
            ),
          );
        }
      }
    }

    return pieChartList;
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      this.imgAsset, {
        Key? key,
        required this.size,
        required this.borderColor,
        this.isTouched = false,
      }) : super(key: key);

  final String imgAsset;
  final double size;
  final Color borderColor;
  final bool isTouched;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isTouched ? size * 1.2 : size,
      height: isTouched ? size * 1.2 : size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isTouched ? 0.6 : 0.4),
            offset: Offset(isTouched ? 4 : 2, isTouched ? 4 : 2),
            blurRadius: isTouched ? 6 : 4,
          ),
        ],
      ),
      padding: EdgeInsets.all((isTouched ? size * 1.2 : size) * 0.15),
      child: Center(child: Image.asset(imgAsset, fit: BoxFit.contain)),
    );
  }
}
