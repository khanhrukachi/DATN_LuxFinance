import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class MyPieChart extends StatefulWidget {
  const MyPieChart({Key? key, required this.list}) : super(key: key);
  final List<Spending> list;

  @override
  State<MyPieChart> createState() => _MyPieChartState();
}

class _MyPieChartState extends State<MyPieChart>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _controller;

  final List<Color> paletteColors = const [
    Color(0xff4e79a7),
    Color(0xff76b7b2),
    Color(0xff59a14f),
    Color(0xfff28e2b),
    Color(0xffe15759),
    Color(0xffff9da7),
    Color(0xff9c755f),
    Color(0xffbab0ac),
    Color(0xffedc948),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              centerSpaceColor:
              isDark ? Colors.white10 : Colors.grey.shade100,
              sections: _buildSections(
                progress: _controller.value,
                context: context,
              ),
            ),
          );
        },
      ),
    );
  }

  List<PieChartSectionData> _buildSections({
    required double progress,
    required BuildContext context,
  }) {
    final List<PieChartSectionData> sections = [];

    if (widget.list.isEmpty) return sections;

    final total = widget.list.fold<int>(
      0,
          (sum, e) => sum + e.money.abs(),
    );

    if (total <= 0) return sections;

    for (int i = 0; i < listType.length; i++) {
      if ([0, 10, 21, 27, 35, 38].contains(i)) continue;

      final data = widget.list.where((e) => e.type == i).toList();
      if (data.isEmpty) continue;

      final sumType =
      data.fold<int>(0, (s, e) => s + e.money.abs());

      final percent = (sumType / total) * 100 * progress;
      final isTouched = sections.length == touchedIndex;

      final key = data.first.typeName ?? "other";
      final title =
      AppLocalizations.of(context).translate(key);

      sections.add(
        PieChartSectionData(
          value: percent,
          color: paletteColors[i % paletteColors.length],
          radius: isTouched ? 108 : 95,
          title: isTouched
              ? "$title\n${percent.toStringAsFixed(1)}%"
              : "",
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black38, blurRadius: 4),
            ],
          ),
          badgeWidget: _Badge(
            listType[i]["image"]!,
            isTouched: isTouched,
          ),
          badgePositionPercentageOffset: 0.95,
        ),
      );
    }

    return sections;
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      this.imgAsset, {
        required this.isTouched,
      });

  final String imgAsset;
  final bool isTouched;

  @override
  Widget build(BuildContext context) {
    final double size = isTouched ? 45 : 35;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.18),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isTouched ? 0.45 : 0.25),
            blurRadius: isTouched ? 6 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(imgAsset, fit: BoxFit.contain),
    );
  }
}
