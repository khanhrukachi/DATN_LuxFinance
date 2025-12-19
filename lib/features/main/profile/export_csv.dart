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
    List<Spending> spendingList = [];
    await FirebaseFirestore.instance
        .collection("data")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get()
        .then((value) async {
      var data = value.data() as Map<String, dynamic>;
      List<String> listData = [];
      for (var entry in data.entries) {
        listData.addAll(
            (entry.value as List<dynamic>).map((e) => e.toString()).toList());
      }

      for (var item in listData) {
        await FirebaseFirestore.instance
            .collection("spending")
            .doc(item)
            .get()
            .then((value) {
          spendingList.add(Spending.fromFirebase(value));
        });
      }
    });

    var excel = Excel.createExcel(); // Create Excel instance
    Sheet sheet = excel['Sheet1']; // Get the sheet

    // Add headers to the sheet
    sheet.appendRow([
      "money",
      "type",
      "note",
      "date",
      "image",
      "location",
      "friends"
    ]);

    // Add data rows to the sheet
    for (var item in spendingList) {
      sheet.appendRow([
        item.money,
        item.type == 41
            ? item.typeName
            : AppLocalizations.of(context)
            .translate(listType[item.type]['title']!) ?? '',
        item.note,
        DateFormat("dd/MM/yyyy - HH:mm:ss").format(item.dateTime),
        item.image,
        item.location,
        item.friends,
      ]);
    }

    // Save the Excel file
    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      }
    } catch (_) {}

    String path =
        "${directory!.path}/TNT_${DateFormat("dd_MM_yyyy_HH_mm_ss").format(DateTime.now())}.xlsx";
    File f = File(path);

    try {
      f.writeAsBytesSync(excel.encode()!);  // Ensure that Excel file is written with UTF-8 encoding
    } catch (e) {
      print("Error writing Excel file: $e");
      Fluttertoast.showToast(
        msg: "Lỗi khi ghi tệp Excel. Vui lòng thử lại.",
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    Fluttertoast.showToast(
      msg:
      "${AppLocalizations.of(context).translate('file_successfully_saved')} $path",
      toastLength: Toast.LENGTH_LONG,
    );
  }
}
