import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class BudgetItem extends StatelessWidget {
  final int type;
  final int spent;
  final int limit;
  final double progress;
  final VoidCallback? onTap;
  final bool isLoading;

  const BudgetItem({
    Key? key,
    required this.type,
    required this.spent,
    required this.limit,
    required this.progress,
    this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isLoading ? _loading(context) : _buildItem(context);
  }

  Widget _buildItem(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, dynamic> typeItem =
    (type >= 0 && type < listType.length) ? listType[type] : {};
    final String titleKey = typeItem['title'] ?? 'other';
    final String? imagePath = typeItem['image'];
    final Color baseColor = typeItem['color'] ?? Colors.blue;
    final bool isOver = progress >= 1.0;
    final double percent = (progress * 100).clamp(0, 999);
    final Color mainColor = isOver ? const Color(0xFFE5533D) : baseColor;
    final Color surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final Color textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: mainColor.withOpacity(isDark ? 0.25 : 0.12),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: mainColor.withOpacity(0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      mainColor.withOpacity(0.30),
                      mainColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: imagePath != null
                    ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(imagePath),
                )
                    : Icon(
                  Icons.category,
                  color: mainColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate(titleKey),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          "${percent.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // PROGRESS BAR
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // SPENT / LIMIT
                    Text(
                      "${_formatCurrency(spent)} / ${_formatCurrency(limit)} đ",
                      style: TextStyle(
                        fontSize: 13,
                        color: isOver ? mainColor : textSecondary,
                        fontWeight:
                        isOver ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ICON END
              Icon(
                isOver ? Icons.warning_amber_rounded : Icons.chevron_right,
                color: mainColor,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            // ICON TYPE SHIMMER
            Shimmer.fromColors(
              baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // TEXT + PROGRESS SHIMMER
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                        child: Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                        child: Container(
                          width: 30,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // PROGRESS BAR
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 9,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // SPENT / LIMIT
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                    child: Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Shimmer.fromColors(
              baseColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    );
  }
}
