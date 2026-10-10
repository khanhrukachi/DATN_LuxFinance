import 'package:flutter/material.dart';

class AuthStyle {
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

/// Local theme: auth screens share the same colors without changing the app theme.
class AuthSurface extends StatelessWidget {
  const AuthSurface({Key? key, required this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final accent = AuthStyle.accent(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: AuthStyle.background(context),
        colorScheme: base.colorScheme.copyWith(primary: accent, secondary: accent,
          surface: AuthStyle.card(context), onSurface: AuthStyle.text(context), onPrimary: AuthStyle.ink),
        textTheme: base.textTheme.apply(bodyColor: AuthStyle.text(context), displayColor: AuthStyle.text(context)),
        appBarTheme: base.appBarTheme.copyWith(backgroundColor: AuthStyle.background(context),
          foregroundColor: AuthStyle.text(context), elevation: 0, surfaceTintColor: Colors.transparent),
        dividerColor: AuthStyle.teal.withOpacity(.15),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: AuthStyle.background(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: AuthStyle.border(AuthStyle.teal.withOpacity(.2)),
          enabledBorder: AuthStyle.border(AuthStyle.teal.withOpacity(.2)),
          focusedBorder: AuthStyle.border(accent, width: 1.5)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          backgroundColor: accent, foregroundColor: AuthStyle.dark(context) ? AuthStyle.ink : Colors.white,
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

class AuthPanel extends StatelessWidget {
  const AuthPanel({Key? key, required this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
      child: Container(decoration: AuthStyle.decoration(context), padding: const EdgeInsets.all(24), child: child))),
  );
}

class AuthEmblem extends StatelessWidget {
  const AuthEmblem({Key? key, required this.icon}) : super(key: key);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(gradient: AuthStyle.gradient,
        borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: AuthStyle.ink, size: 30)),
      const SizedBox(height: 12),
      Text('LuxFinance', style: TextStyle(color: AuthStyle.accent(context), fontWeight: FontWeight.w700,
        fontSize: 13, letterSpacing: 1.2)),
    ]),
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({Key? key, required this.text, required this.onPressed, this.icon}) : super(key: key);
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity,
    child: Material(
      color: onPressed == null ? AuthStyle.muted(context).withOpacity(.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
      child: Ink(decoration: BoxDecoration(gradient: onPressed == null ? null : AuthStyle.gradient,
        borderRadius: BorderRadius.circular(16)),
        child: TextButton(onPressed: onPressed, style: TextButton.styleFrom(
          foregroundColor: AuthStyle.ink, disabledForegroundColor: AuthStyle.muted(context),
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
