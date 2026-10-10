import 'package:flutter/material.dart';

class ProfileStyle {
  static const cyan = Color(0xFF00D2FF);
  static const teal = Color(0xFF2DD8C6);
  static const ink = Color(0xFF073D43);
  static bool dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) => dark(context) ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);
  static Color card(BuildContext context) => dark(context) ? const Color(0xFF172A30) : Colors.white;
  static Color accent(BuildContext context) => dark(context) ? teal : const Color(0xFF14988F);
  static Color text(BuildContext context) => dark(context) ? const Color(0xFFE6EEF0) : const Color(0xFF193A43);
  static Color muted(BuildContext context) => text(context).withOpacity(.65);
  static const gradient = LinearGradient(colors: [cyan, teal], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: width));
  static InputDecoration input(BuildContext context, String hint, {IconData? icon, String? error, Widget? suffix}) => InputDecoration(
    hintText: hint, errorText: error, errorMaxLines: 3, filled: true,
    fillColor: background(context), hintStyle: TextStyle(color: muted(context), fontSize: 14),
    prefixIcon: icon == null ? null : Icon(icon, color: accent(context), size: 20),
    suffixIcon: suffix, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: border(teal.withOpacity(.2)), enabledBorder: border(teal.withOpacity(.2)),
    focusedBorder: border(accent(context), width: 1.5),
    errorBorder: border(const Color(0xFFE5533D)), focusedErrorBorder: border(const Color(0xFFE5533D), width: 1.5));
  static BoxDecoration decoration(BuildContext context) => BoxDecoration(
    color: card(context), borderRadius: BorderRadius.circular(24),
    border: Border.all(color: teal.withOpacity(.16)),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark(context) ? .08 : .025), blurRadius: 20, offset: const Offset(0, 6))]);
}

/// Local theme: profile screens share the same colors without changing the app theme.
class ProfileSurface extends StatelessWidget {
  const ProfileSurface({Key? key, required this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final accent = ProfileStyle.accent(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: ProfileStyle.background(context),
        colorScheme: base.colorScheme.copyWith(primary: accent, secondary: accent,
          surface: ProfileStyle.card(context), onSurface: ProfileStyle.text(context), onPrimary: ProfileStyle.ink),
        textTheme: base.textTheme.apply(bodyColor: ProfileStyle.text(context), displayColor: ProfileStyle.text(context)),
        appBarTheme: base.appBarTheme.copyWith(backgroundColor: ProfileStyle.background(context),
          foregroundColor: ProfileStyle.text(context), elevation: 0, surfaceTintColor: Colors.transparent),
        dividerColor: ProfileStyle.teal.withOpacity(.15),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: ProfileStyle.background(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: ProfileStyle.border(ProfileStyle.teal.withOpacity(.2)),
          enabledBorder: ProfileStyle.border(ProfileStyle.teal.withOpacity(.2)),
          focusedBorder: ProfileStyle.border(accent, width: 1.5)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          backgroundColor: accent, foregroundColor: ProfileStyle.dark(context) ? ProfileStyle.ink : Colors.white,
          elevation: 0, minimumSize: const Size(0, 52), shape: shape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent, shape: shape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          selectedColor: accent, selectedTileColor: accent.withOpacity(.1)),
      ),
      child: child,
    );
  }
}

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({Key? key, required this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
      child: Container(decoration: ProfileStyle.decoration(context), padding: const EdgeInsets.all(24), child: child))),
  );
}

class ProfileEmblem extends StatelessWidget {
  const ProfileEmblem({Key? key, required this.icon}) : super(key: key);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(gradient: ProfileStyle.gradient,
        borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: ProfileStyle.ink, size: 30)),
      const SizedBox(height: 12),
      Text('LuxFinance', style: TextStyle(color: ProfileStyle.accent(context), fontWeight: FontWeight.w700,
        fontSize: 13, letterSpacing: 1.2)),
    ]),
  );
}

class ProfileButton extends StatelessWidget {
  const ProfileButton({Key? key, required this.text, required this.onPressed, this.icon}) : super(key: key);
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity,
    child: Material(
      color: onPressed == null ? ProfileStyle.muted(context).withOpacity(.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
      child: Ink(decoration: BoxDecoration(gradient: onPressed == null ? null : ProfileStyle.gradient,
        borderRadius: BorderRadius.circular(16)),
        child: TextButton(onPressed: onPressed, style: TextButton.styleFrom(
          foregroundColor: ProfileStyle.ink, disabledForegroundColor: ProfileStyle.muted(context),
          minimumSize: const Size(0, 54), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(text, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ]))),
    ),
  );
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({Key? key, required this.title, this.value, required this.icon,
    this.onTap, this.color}) : super(key: key);
  final String title;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final accent = color ?? ProfileStyle.accent(context);
    return Material(color: ProfileStyle.card(context), clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ProfileStyle.teal.withOpacity(.16))),
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(
            color: accent.withOpacity(.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: accent, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: value == null ? 14 : 12,
              fontWeight: value == null ? FontWeight.w600 : FontWeight.w500,
              color: value == null ? ProfileStyle.text(context) : ProfileStyle.muted(context))),
            if (value != null) ...[const SizedBox(height: 5),
              Text(value!.isEmpty ? '—' : value!, style: TextStyle(fontSize: 15,
                height: 1.4, fontWeight: FontWeight.w600, color: ProfileStyle.text(context)))],
          ])),
          if (onTap != null) ...[const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: ProfileStyle.accent(context), size: 22)],
        ]))),
    );
  }
}

class ProfileSelection extends StatelessWidget {
  const ProfileSelection({Key? key, required this.value, required this.onTap}) : super(key: key);
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: ProfileStyle.background(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: ProfileStyle.teal.withOpacity(.2))), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(children: [Expanded(child: Text(value, style: TextStyle(fontSize: 14,
          color: ProfileStyle.text(context)))), const SizedBox(width: 8),
          Icon(Icons.expand_more_rounded, color: ProfileStyle.accent(context))]))),
  );
}

class ProfilePickerDialog extends StatelessWidget {
  const ProfilePickerDialog({Key? key, required this.title, required this.child, this.footer}) : super(key: key);
  final String title;
  final Widget child;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => ProfileSurface(child: Dialog(
    backgroundColor: ProfileStyle.card(context), surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias, insetPadding: const EdgeInsets.all(20),
    child: SizedBox(width: 440, height: MediaQuery.of(context).size.height * .6,
      child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ProfileStyle.text(context))),
          const SizedBox(height: 14), Expanded(child: child),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]))),
  ));
}

class ProfileEmpty extends StatelessWidget {
  const ProfileEmpty({Key? key, required this.icon, required this.text}) : super(key: key);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(
        color: ProfileStyle.accent(context).withOpacity(.1), borderRadius: BorderRadius.circular(24)),
        child: Icon(icon, size: 32, color: ProfileStyle.accent(context))),
      const SizedBox(height: 16), Text(text, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.5, color: ProfileStyle.muted(context))),
    ])));
}
