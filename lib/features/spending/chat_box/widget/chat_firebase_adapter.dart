import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/models/spending.dart';

import 'chat_intent.dart';

class ChatFirebaseAdapter {
  static Future<void> addDraft(ChatTransactionDraft draft) async {
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

    await SpendingFirebase.addSpending(spending);
  }
}
