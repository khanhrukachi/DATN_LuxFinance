import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/spending.dart';

import 'chat_intent.dart';

class ChatFirebaseAdapter {
  static Future<void> addDraft(ChatTransactionDraft draft) async {
    final category = Map<String, dynamic>.from(
      listType[draft.type] as Map,
    );

    final categoryId =
    (category['id'] ?? category['title'])?.toString();
    final parentId = category['parent']?.toString();

    final parentIndex = listType.indexWhere(
          (item) => item['id']?.toString() == parentId,
    );

    final parentName = parentIndex >= 0
        ? listType[parentIndex]['title']?.toString()
        : null;

    final spending = Spending(
      money: draft.signedMoney,
      type: draft.type,
      typeName: draft.typeName,
      dateTime: draft.date,
      note: draft.note,
      image: null,
      location: draft.location,
      friends: const [],
    );

    await SpendingFirebase.addSpending(
      spending,
      categoryId: categoryId,
      parentId: parentId,
      parentName: parentName,
    );
  }
}