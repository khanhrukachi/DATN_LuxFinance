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

    // ===== THRESHOLD LOGIC =====
    final bool isWarning = progress >= 0.8 && progress < 1.0;
    final bool isOver = progress >= 1.0;

    final Color warningColor = Colors.orange;
    final Color dangerColor = const Color(0xFFE5533D);

    final Color mainColor = isOver
        ? dangerColor
        : isWarning
        ? warningColor
        : baseColor;

    final double percent = (progress * 100).clamp(0, 999);

    final Color surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final Color textSecondary =
    isDark ? Colors.grey.shade400 : Colors.grey.shade700;

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
              color: mainColor.withOpacity(isDark ? 0.3 : 0.15),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: mainColor.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            children: [
              // ICON CATEGORY
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      mainColor.withOpacity(0.35),
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

              // CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE + %
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
                        valueColor:
                        AlwaysStoppedAnimation<Color>(mainColor),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // SPENT / LIMIT
                    Text(
                      "${_formatCurrency(spent)} / ${_formatCurrency(limit)} đ",
                      style: TextStyle(
                        fontSize: 13,
                        color: (isWarning || isOver)
                            ? mainColor
                            : textSecondary,
                        fontWeight: (isWarning || isOver)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // STATUS ICON
              Icon(
                isOver
                    ? Icons.warning_rounded
                    : isWarning
                    ? Icons.warning_amber_rounded
                    : Icons.chevron_right,
                color: mainColor,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= LOADING =================
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
            Shimmer.fromColors(
              baseColor:
              isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              highlightColor:
              isDark ? Colors.grey.shade600 : Colors.grey.shade100,
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor:
                    isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    highlightColor:
                    isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                    child: Container(
                      width: 140,
                      height: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Shimmer.fromColors(
                    baseColor:
                    isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    highlightColor:
                    isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                    child: Container(
                      height: 9,
                      color: Colors.grey,
                    ),
                  ),
                ],
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
