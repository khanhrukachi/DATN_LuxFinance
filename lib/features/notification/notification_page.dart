import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _NotificationItem(
            title: "Cảnh báo chi tiêu",
            content: "Bạn đã vượt 20% ngân sách ăn uống hôm nay",
            icon: Icons.warning,
            color: Colors.redAccent,
            time: "10:35 • 21/01/2026",
          ),
          _NotificationItem(
            title: "Gợi ý AI",
            content: "Bạn có thể tiết kiệm 500.000đ nếu giảm chi tiêu cà phê",
            icon: Icons.lightbulb,
            color: Colors.orange,
            time: "09:10 • 21/01/2026",
          ),
          _NotificationItem(
            title: "Nhắc nhở",
            content: "Hôm nay bạn chưa ghi nhận chi tiêu nào",
            icon: Icons.notifications,
            color: Colors.blue,
            time: "08:00 • 21/01/2026",
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;
  final String time;

  const _NotificationItem({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(content),
        ),
      ),
    );
  }
}
