import 'package:flutter/material.dart';

class AnomalyEmptyCard extends StatelessWidget {
  final bool isDarkMode;
  final bool analysisReliable;
  final bool isError;
  final String? message;

  const AnomalyEmptyCard({
    super.key,
    required this.isDarkMode,
    this.analysisReliable = false,
    this.isError = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.orange : analysisReliable ? Colors.teal : Colors.blueGrey;
    final title = isError ? 'Chưa có kết quả phân tích'
        : analysisReliable ? 'Chưa phát hiện dấu hiệu bất thường'
        : 'Chưa đủ cơ sở để kết luận';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(isError ? Icons.info_outline : analysisReliable ? Icons.check_circle_outline : Icons.hourglass_empty,
            color: color, size: 42),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text(message ?? (analysisReliable
            ? 'Kết quả áp dụng cho dữ liệu đã gửi. Hãy tiếp tục kiểm tra và ghi nhận giao dịch đầy đủ.'
            : 'Cập nhật thêm lịch sử chi tiêu để hệ thống có dữ liệu đối chiếu.'),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: isDarkMode ? Colors.white70 : Colors.black54)),
      ]),
    );
  }
}
