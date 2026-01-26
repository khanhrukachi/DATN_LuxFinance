import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class TrendPredictionSection extends StatelessWidget {
  final List<PredictedValue> predictions;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const TrendPredictionSection({
    Key? key,
    required this.predictions,
    required this.isDarkMode,
    required this.numberFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) return const SizedBox();

    final bgColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final shadowColor = isDarkMode ? Colors.black45 : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: predictions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return TrendPredictionRow(
            prediction: predictions[index],
            isDarkMode: isDarkMode,
            numberFormat: numberFormat,
          );
        },
      ),
    );
  }
}

class TrendPredictionRow extends StatelessWidget {
  final PredictedValue prediction;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const TrendPredictionRow({
    Key? key,
    required this.prediction,
    required this.isDarkMode,
    required this.numberFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String formattedDate = prediction.date;
    try {
      formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(prediction.date));
    } catch (_) {}

    final rowColor = isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA);
    final borderColor = isDarkMode ? Colors.white10 : Colors.transparent;
    final labelColor = isDarkMode ? Colors.white60 : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ngày dự báo",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: isDarkMode ? Colors.blueAccent[100] : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDarkMode ? Colors.blueAccent[100] : const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    "Thu nhập: ",
                    style: TextStyle(fontSize: 12, color: labelColor),
                  ),
                  Text(
                    "+${numberFormat.format(prediction.predictedIncome)}",
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    "Chi tiêu: ",
                    style: TextStyle(fontSize: 12, color: labelColor),
                  ),
                  Text(
                    "-${numberFormat.format(prediction.predictedExpense)}",
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}