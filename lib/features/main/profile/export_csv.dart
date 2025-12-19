import 'dart:io';

import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ExportCSV {
  static Future<void> exportCSV(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      /// ================= LẤY ID SPENDING =================
      final dataSnapshot = await FirebaseFirestore.instance
          .collection("data")
          .doc(uid)
          .get();

      if (!dataSnapshot.exists || dataSnapshot.data() == null) {
        Fluttertoast.showToast(msg: "Không có dữ liệu để xuất");
        return;
      }

      final data = dataSnapshot.data() as Map<String, dynamic>;
      final Set<String> spendingIds = {};

      for (final entry in data.entries) {
        if (entry.value is List) {
          spendingIds.addAll(
            (entry.value as List).map((e) => e.toString()),
          );
        }
      }

      /// ================= LẤY SPENDING =================
      final List<Spending> spendingList = [];

      for (final id in spendingIds) {
        final doc = await FirebaseFirestore.instance
            .collection("spending")
            .doc(id)
            .get();

        if (doc.exists && doc.data() != null) {
          spendingList.add(Spending.fromFirebase(
              doc as QueryDocumentSnapshot<Map<String, dynamic>>));
        }
      }

      if (spendingList.isEmpty) {
        Fluttertoast.showToast(msg: "Không có dữ liệu để xuất");
        return;
      }

      /// ================= EXCEL =================
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      sheet.appendRow([
        "Money",
        "Type",
        "Note",
        "Date",
        "Image",
        "Location",
        "Friends",
      ]);

      for (final item in spendingList) {
        sheet.appendRow([
          item.money,
          item.type == 41
              ? (item.typeName ?? "")
              : AppLocalizations.of(context)
              .translate(listType[item.type]['title'] ?? '') ??
              '',
          item.note ?? "",
          DateFormat("dd/MM/yyyy HH:mm:ss").format(item.dateTime),
          item.image ?? "",
          item.location ?? "",
          (item.friends ?? []).join(", "),
        ]);
      }

      /// ================= SAVE FILE =================
      Directory directory;

      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = (await getExternalStorageDirectory())!;
        }
      }

      final path =
          "${directory.path}/TNT_${DateFormat("dd_MM_yyyy_HH_mm_ss").format(DateTime.now())}.xlsx";

      final file = File(path);
      file.writeAsBytesSync(excel.encode()!);

      Fluttertoast.showToast(
        msg:
        "${AppLocalizations.of(context).translate('file_successfully_saved')} $path",
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      debugPrint("EXPORT EXCEL ERROR: $e");
      Fluttertoast.showToast(
        msg: "Lỗi khi xuất file Excel",
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }
}
