import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/circle_text.dart';
import 'package:personal_financial_management/features/spending/edit_spending/edit_spending_screen.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/view_spending/view_image.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

class ViewSpendingPage extends StatefulWidget {
  const ViewSpendingPage({
    Key? key,
    required this.spending,
    this.delete,
    this.change,
  }) : super(key: key);

  final Spending spending;
  final Function(String id)? delete;
  final Function(Spending spending)? change;

  @override
  State<ViewSpendingPage> createState() => _ViewSpendingPageState();
}

class _ViewSpendingPageState extends State<ViewSpendingPage> {
  List<Color> colors = [];
  ScreenshotController screenshotController = ScreenshotController();
  Spending? spending;

  @override
  void initState() {
    super.initState();
    spending = widget.spending;
    final friends = spending?.friends ?? [];
    for (var _ in friends) {
      colors.add(SpendingStyle.teal);
    }
  }

  bool get isValid => spending != null && spending!.id != null;

  void showInvalidSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể mở giao dịch này')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isValid) {
      return Scaffold(
        backgroundColor: SpendingStyle.background(context),
        appBar: AppBar(
          title: const Text('Lỗi'),
        ),
        body: const Center(
          child: Text('Không thể mở giao dịch này'),
        ),
      );
    }

    final typeConfig = spending!.type >= 0 && spending!.type < listType.length
        ? listType[spending!.type] : <String, String>{};

    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SpendingStyle.background(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: SpendingStyle.accent(context)),
            onPressed: () async {
              if (!isValid) {
                showInvalidSnackBar();
                return;
              }
              final image = await screenshotController.capture(
                  delay: const Duration(milliseconds: 10));
              if (image == null) return;
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/spending.png');
              await file.writeAsBytes(image);
              await Share.shareXFiles([XFile(file.path)]);
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: SpendingStyle.accent(context)),
            onPressed: () {
              if (!isValid) {
                showInvalidSnackBar();
                return;
              }
              Navigator.push(
                context,
                createRoute(
                  screen: EditSpendingPage(
                    spending: spending!,
                    change: (updated, newColors) async {
                      try {
                        updated.image = await FirebaseStorage.instance
                            .ref("spending/${updated.id}.png")
                            .getDownloadURL();
                      } catch (_) {}
                      widget.change?.call(updated);
                      if (!mounted) return;
                      setState(() {
                        spending = updated;
                        colors = newColors;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: SpendingStyle.danger),
            onPressed: () {
              if (!isValid) {
                showInvalidSnackBar();
                return;
              }
              showConfirmDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Screenshot(
          controller: screenshotController,
          child: Container(
            color: SpendingStyle.background(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(padding: const EdgeInsets.all(20),
                decoration: SpendingStyle.decoration(context, hero: true),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 52, height: 52, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: SpendingStyle.teal.withOpacity(.12),
                          borderRadius: BorderRadius.circular(16)),
                      child: typeConfig['image'] == null
                          ? Icon(Icons.category_outlined, color: SpendingStyle.accent(context))
                          : Image.asset(typeConfig['image']!,
                          errorBuilder: (_, __, ___) => Icon(Icons.category_outlined, color: SpendingStyle.accent(context))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                        spending!.type == 41 || spending!.categoryId == 'custom'
                            ? (spending!.typeName ?? '')
                            : AppLocalizations.of(context).translate(typeConfig['title'] ?? 'other'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 20),
                  Text(NumberFormat.currency(
                      locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
                      symbol: '₫', decimalDigits: 0).format(spending!.money.abs()),
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700,
                          color: spending!.money < 0 ? SpendingStyle.danger : SpendingStyle.accent(context))),
                ]),
              ),
              const SizedBox(height: 14),
              Container(padding: const EdgeInsets.all(16), decoration: SpendingStyle.decoration(context),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _infoRow(Icons.calendar_month_rounded,
                      DateFormat('dd/MM/yyyy · HH:mm').format(spending!.dateTime)),
                  if ((spending!.note ?? '').isNotEmpty)
                    _infoRow(Icons.edit_note_rounded, spending!.note!),
                  if ((spending!.location ?? '').isNotEmpty)
                    _infoRow(Icons.location_on_outlined, spending!.location!),
                  if (spending!.friends.isNotEmpty) ...[
                    const SizedBox(height: 8), addFriend(),
                  ],
                ]),
              ),
              if ((spending!.image ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                Material(color: SpendingStyle.card(context), borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ViewImage(url: spending!.image!))),
                    child: CachedNetworkImage(imageUrl: spending!.image!, width: double.infinity,
                      fit: BoxFit.fitWidth,
                      placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: SpendingStyle.card(context),
                          highlightColor: SpendingStyle.teal.withOpacity(.16),
                          child: Container(height: 180, color: Colors.white)),
                      errorWidget: (_, __, ___) => SizedBox(height: 140,
                          child: Icon(Icons.broken_image_outlined, size: 36, color: SpendingStyle.muted(context))),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SpendingFieldIcon(icon: icon), const SizedBox(width: 12),
      Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5)))),
    ]),
  );

  Widget addFriend() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SpendingFieldIcon(icon: Icons.people_outline_rounded), const SizedBox(width: 12),
    Expanded(child: Wrap(spacing: 8, runSpacing: 8,
      children: List.generate(spending!.friends.length, (i) {
        final name = spending!.friends[i];
        return Container(padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(color: SpendingStyle.teal.withOpacity(.08),
              borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            circleText(text: name.isEmpty ? '?' : name.substring(0, 1), color: SpendingStyle.teal),
            const SizedBox(width: 8), Flexible(child: Text(name, style: const TextStyle(fontSize: 14))),
          ]),
        );
      }),
    )),
  ]);

  Future<void> showConfirmDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: SpendingStyle.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Center(
          child: Text(
            AppLocalizations.of(context).translate('you_want_delete'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SpendingStyle.danger, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              loadingAnimation(context);

              await SpendingFirebase.deleteSpending(spending!);

              if (spending!.id != null) {
                widget.delete?.call(spending!.id!);
              }

              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

}
