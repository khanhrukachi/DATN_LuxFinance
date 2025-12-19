import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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
  final numberFormat = NumberFormat.currency(locale: "vi_VI");
  ScreenshotController screenshotController = ScreenshotController();
  Spending? spending;

  @override
  void initState() {
    super.initState();
    spending = widget.spending;
    // Tạo màu cho friends nếu có
    final friends = spending?.friends ?? [];
    for (var _ in friends) {
      colors.add(Color.fromRGBO(Random().nextInt(255), Random().nextInt(255),
          Random().nextInt(255), 1));
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
      // Màn hình lỗi nếu dữ liệu không hợp lệ
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lỗi'),
        ),
        body: const Center(
          child: Text('Không thể mở giao dịch này'),
        ),
      );
    }

    final typeConfig = listType[spending!.type];

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF1272D8)),
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
            icon: const Icon(Icons.edit, color: Color(0xFFE7BB12)),
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
            icon: const Icon(Icons.delete, color: Color(0xFFFF0018)),
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
        child: Screenshot(
          controller: screenshotController,
          child: Card(
            margin: const EdgeInsets.all(10),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  Row(
                    children: [
                      if (typeConfig != null && typeConfig["image"] != null)
                        Image.asset(typeConfig["image"]!, height: 50)
                      else
                        const Icon(Icons.money, size: 50),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          spending!.type == 41
                              ? (spending!.typeName ?? '')
                              : typeConfig != null
                              ? AppLocalizations.of(context).translate(
                              typeConfig["title"] ?? '')
                              : '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // MONEY
                  Row(
                    children: [
                      const SizedBox(width: 60),
                      Text(
                        numberFormat.format(spending!.money.abs()),
                        style:
                        const TextStyle(fontSize: 25, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Divider(thickness: 0.5),
                  const SizedBox(height: 5),

                  // DATE
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          size: 30, color: Color(0xFFF4831B)),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat("dd/MM/yyyy - HH:mm")
                            .format(spending!.dateTime),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  // NOTE
                  if ((spending!.note ?? '').isNotEmpty)
                    _infoRow(Icons.edit_note_rounded, spending!.note!),

                  // LOCATION
                  if ((spending!.location ?? '').isNotEmpty)
                    _infoRow(Icons.location_on_outlined, spending!.location!),

                  // FRIENDS
                  if ((spending!.friends ?? []).isNotEmpty) addFriend(),

                  // IMAGE
                  if (spending!.image != null)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ViewImage(url: spending!.image!),
                          ),
                        );
                      },
                      child: CachedNetworkImage(
                        imageUrl: spending!.image!,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            color: Colors.grey,
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 30),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  Widget addFriend() {
    final friends = spending!.friends ?? [];
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(friends.length, (i) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.7),
            borderRadius: BorderRadius.circular(90),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              circleText(text: friends[i][0], color: colors[i]),
              const SizedBox(width: 5),
              Text(friends[i]),
            ],
          ),
        );
      }),
    );
  }

  Future<void> showConfirmDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Center(
            child:
            Text(AppLocalizations.of(context).translate('you_want_delete'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              loadingAnimation(context);
              await SpendingFirebase.deleteSpending(spending!);
              if (spending!.id != null) {
                widget.delete?.call(spending!.id!);
              }
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
