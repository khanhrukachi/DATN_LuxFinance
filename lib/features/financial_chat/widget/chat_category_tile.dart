import 'package:flutter/material.dart';

class ChatCategoryTile extends StatelessWidget {
  const ChatCategoryTile({
    super.key,
    required this.name,
    required this.isParent,
    required this.parentBackground,
    required this.onTap,
  });

  final String name;
  final bool isParent;
  final Color parentBackground;
  final VoidCallback onTap;

  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [Color(0xFF00D2FF), _teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? _teal : const Color(0xFF14988F);
    return Padding(
      padding: EdgeInsets.only(
        left: isParent ? 0 : 12,
        top: isParent ? 12 : 0,
        bottom: 8,
      ),
      child: Material(
        color: isParent ? parentBackground : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _teal.withOpacity(isParent ? .24 : .12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: _teal.withOpacity(.14),
          highlightColor: _teal.withOpacity(.06),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isParent ? null : _teal.withOpacity(.10),
                    gradient: isParent ? _gradient : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isParent ? Icons.folder_rounded : Icons.label_outline_rounded,
                    size: 22,
                    color: isParent ? const Color(0xFF073D43) : accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isParent ? 15 : 14,
                      height: 1.4,
                      fontWeight: isParent ? FontWeight.w700 : FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 22, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
