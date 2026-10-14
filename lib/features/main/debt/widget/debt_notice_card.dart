import 'package:flutter/material.dart';

class DebtNoticeCard extends StatelessWidget {
  const DebtNoticeCard({
    required this.message,
    required this.color,
    required this.backgroundColor,
    required this.warningNotice,
    required this.onClose,
  });

  final String message;
  final Color color;
  final Color backgroundColor;
  final bool warningNotice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: backgroundColor,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(.22)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  warningNotice
                      ? Icons.warning_amber_rounded
                      : Icons.error_outline_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: color, size: 20),
              ),
            ],
          ),
        ),
      );
}
