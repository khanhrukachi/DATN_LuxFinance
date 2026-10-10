import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
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
  int? _touchedCategory;
  late AnimationController _controller;

  final List<Color> paletteColors = AnalyticStyle.palette;

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

    final categoryIds = <int>[
      for (int i = 0; i < listType.length; i++)
        if (![0, 10, 21, 27, 35, 38].contains(i) &&
            widget.list.any((e) => e.type == i && e.money != 0))
          i,
    ];
    if (!categoryIds.contains(_touchedCategory)) _touchedCategory = null;

    final sections = _buildSections(
      progress: _controller.value,
      context: context,
    );

    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('no_data'),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index = response?.touchedSection?.touchedSectionIndex;
                  final int? category = event.isInterestedForInteractions &&
                      index != null && index >= 0 && index < categoryIds.length
                      ? categoryIds[index]
                      : null;
                  if (mounted && category != _touchedCategory) {
                    setState(() => _touchedCategory = category);
                  }
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 30,
              centerSpaceColor:
              AnalyticStyle.background(context),
              sections: _buildSections(progress: _controller.value, context: context),
            ),
            // Never interpolate sections against a different badge list.
            key: ValueKey<String>('pie-${categoryIds.join('-')}'),
            duration: Duration.zero,
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

      if (sumType <= 0) continue;

      final percent = (sumType / total) * 100;
      final isTouched = i == _touchedCategory;

      final key = listType[i]['title'] ?? data.first.typeName ?? 'other';
      final title =
      AppLocalizations.of(context).translate(key);

      sections.add(
        PieChartSectionData(
          value: percent,
          color: paletteColors[i % paletteColors.length],
          radius: ((MediaQuery.of(context).size.width - 64) * .22)
              .clamp(44.0, 88.0).toDouble() * (.85 + .15 * progress) + (isTouched ? 8 : 0),
          title: isTouched
              ? '$title\n${percent.toStringAsFixed(1)}%'
              : '',
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black38, blurRadius: 4),
            ],
          ),
          badgeWidget: _Badge(
            listType[i]['image'],
            isTouched: isTouched,
            key: ValueKey<int>(i),
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
        Key? key,
        required this.isTouched,
      }) : super(key: key);

  final String? imgAsset;
  final bool isTouched;

  @override
  Widget build(BuildContext context) {
    final double size = isTouched ? 45 : 35;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.18),
      decoration: BoxDecoration(
        color: AnalyticStyle.card(context),
        shape: BoxShape.circle,
        border: Border.all(color: AnalyticStyle.teal.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isTouched ? 0.16 : 0.08),
            blurRadius: isTouched ? 6 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: imgAsset == null ? Icon(Icons.label_outline_rounded, color: AnalyticStyle.accent(context), size: 18)
          : Image.asset(imgAsset!, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.label_outline_rounded, color: AnalyticStyle.accent(context), size: 18)),
    );
  }
}
