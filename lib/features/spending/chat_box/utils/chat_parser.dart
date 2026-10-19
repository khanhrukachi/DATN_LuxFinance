import 'package:flutter/widgets.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/core/constants/list.dart';

import 'category_matcher.dart';
import 'category_semantics.dart';
import 'transaction_action_keywords.dart';
import 'transaction_location_parser.dart';
import '../model/chat_intent.dart';

/// Bộ phân tích câu nhập giao dịch dạng tự nhiên.
/// Hỗ trợ số tiền, ngày tương đối/ngày cụ thể, giờ, địa điểm và ghi chú.
class ChatParser {
  static const Set<String> _categoryKeys = {
    'market',
    'eating',
    'move',
    'rent_house',
    'water_money',
    'telephone_fee',
    'electricity_bill',
    'gas_money',
    'tv_money',
    'internet_money',
    'repair_and_decorate_the_house',
    'vehicle_maintenance',
    'physical_examination',
    'insurance',
    'education',
    'housewares',
    'personal_belongings',
    'pet',
    'other_costs',
    'sport',
    'beautify',
    'gifts_donations',
    'online_services',
    'fun_play',
    'invest',
    'earn_profit',
    'salary',
    'other_income',
  };

  static String categoryLabel(String key, BuildContext context) {
    return AppLocalizations.of(context).translate(key);
  }

  static String normalize(String value) => _fold(value);

  static bool isCancel(String value) => RegExp(
    r'^(huy|huy giao dich|bo qua|thoi|cancel|cancel transaction)$',
  ).hasMatch(_fold(value));

  static bool isNewTransaction(String value) => RegExp(
    r'^(giao dich moi|khoan moi|bat dau lai|new transaction|start over)$',
  ).hasMatch(_fold(value));

  static bool isSave(String value) => RegExp(
    r'^(luu|luu giao dich|xac nhan|save|save transaction|confirm)$',
  ).hasMatch(_fold(value));

  /// Merge explicit fields only; an amount reply never resets date or category.
  static ChatParseResult parseTurn(
      String raw,
      BuildContext context,
      ChatConversationMemory memory,
      ) {
    final text = raw.trim();
    final folded = _fold(text);
    if (RegExp(r'^(chao|xin chao|hello|hi|cam on|thanks)$').hasMatch(folded)) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_record_example_prompt'),
      );
    }
    if (RegExp(
      r'\b(bao nhieu|nhu nao|the nao|thong ke|so sanh|du bao|tong quan|how much|compare|forecast)\b',
    ).hasMatch(folded)) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_analysis_guidance'),
      );
    }
    // Metadata is text, never a second transaction amount or category.
    final metadataOnly =
        RegExp(
          r'^(?:ghi chu|note|dia diem|location)\s*[:：]?\s+',
        ).hasMatch(folded) ||
            RegExp(r'^(?:ghi chu|note|dia diem|location)\s*[:：]').hasMatch(folded);
    final categoryText = _categoryText(text);
    if (!metadataOnly && RegExp(
      r'\b(thu no|tra no|cho vay|di vay|vay tien|muon tien|tra lai vay|repay|repaying|borrow money|lend money|debt repayment|debt collection)\b',
    ).hasMatch(_fold(categoryText))) {
      return ChatParseResult.question(AppLocalizations.of(context)
          .translate('financial_secretary_debt_ledger_prompt'));
    }
    final pendingTerm = memory.ambiguousTerm;
    final analysis = metadataOnly
        ? const CategoryAnalysis([], [], false)
        : CategoryMatcher.analyze(categoryText);
    final categoryReplyKeys = metadataOnly
        ? <String>[]
        : CategorySemantics.categoryReplyChoices(
        _fold(categoryText),
        {for (final key in memory.categoryCandidates)
          key: _fold(categoryLabel(key, context))},
        memory.categoryCandidates);
    final categoryReplyOptions = <CategoryMatch>[];
    for (final key in categoryReplyKeys) {
      final index = listType.indexWhere((e) => e['title'] == key && e['isParent'] != 'true');
      if (index >= 0) categoryReplyOptions.add(CategoryMatch(index, key, 0.9));
    }
    final isCategoryReply = categoryReplyOptions.isNotEmpty;
    final replyKey = metadataOnly ? null : CategorySemantics.resolveReply(pendingTerm, _fold(categoryText));
    final replyIndex = replyKey == null ? -1 : listType.indexWhere(
            (e) => e['title'] == replyKey && e['isParent'] != 'true');
    final resolvedReply = replyKey != null && replyIndex >= 0;
    final options = isCategoryReply
        ? categoryReplyOptions
        : resolvedReply
        ? <CategoryMatch>[CategoryMatch(replyIndex, replyKey!, 0.9)]
        : analysis.matches;
    final match = options.length == 1 ? options.first : null;
    if (!metadataOnly && RegExp(r'(\$|€|£|\b(?:usd|eur|gbp|dollar|dollars|euro|euros)\b)').hasMatch(folded)) {
      return ChatParseResult.question(AppLocalizations.of(context)
          .translate('financial_secretary_vnd_only_prompt'));
    }
    if (!metadataOnly && RegExp(r'(?<![a-z0-9])0+(?:[.,]0+)?\s*(?:k|tr|trieu|nghin|ngan|dong|vnd|d)(?![a-z0-9])').hasMatch(folded)) {
      return ChatParseResult.question(AppLocalizations.of(context)
          .translate('financial_secretary_positive_amount_required'));
    }
    if (!metadataOnly && _hasMultipleAmounts(text)) {
      return ChatParseResult.question(AppLocalizations.of(context)
          .translate('financial_secretary_one_amount_prompt'));
    }
    if (!metadataOnly && TransactionActionKeywords.unrealized.hasMatch(folded)) {
      return ChatParseResult.question(AppLocalizations.of(context)
          .translate('financial_secretary_actual_transaction_prompt'));
    }
    final ambiguousCategory = match == null && options.isNotEmpty;

    if (match != null &&
        (!_categoryKeys.contains(match.key) ||
            !listType.any(
                  (item) =>
              item['title'] == match.key && item['isParent'] != 'true',
            ))) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_specific_category_prompt'),
      );
    }
    final parsedDate = metadataOnly ? null : _date(categoryText);
    final parsedTime = metadataOnly ? null : _time(categoryText);
    final hasDate = RegExp(
      r'\b\d{1,2}\s*[/-]\s*\d{1,2}|\bngay\s*\d|\b\d{1,2}\s*thang\s*\d',
    ).hasMatch(folded);
    final hasTime =
        _timePattern.hasMatch(folded) ||
            RegExp(r'\b\d{1,2}\s+(?:sang|trua|chieu|toi|am|pm)\b').hasMatch(folded);
    if (!metadataOnly &&
        ((hasDate && parsedDate == null) || (hasTime && parsedTime == null))) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_invalid_datetime_kept'),
      );
    }
    final amount = metadataOnly ? null : _amount(text);
    if (!metadataOnly &&
        (RegExp(r"(^|\s)-\s*\d").hasMatch(folded) ||
            RegExp(
              r'^0+(?:[.,]0+)?\s*(?:k|tr|d|dong)?$',
            ).hasMatch(folded))) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_positive_amount_required'),
      );
    }
    final noteUpdate = RegExp(
      r'^(?:ghi chu|note)\s*[:：]?\s*(.+)$',
    ).firstMatch(folded);
    final locationUpdate = RegExp(
      r'^(?:dia diem|location)\s*[:：]?\s*(.+)$',
    ).firstMatch(folded);
    final location = metadataOnly ? '' : _location(text);
    if (match == null &&
        amount == null &&
        parsedDate == null &&
        parsedTime == null &&
        noteUpdate == null &&
        locationUpdate == null &&
        location.isEmpty &&
        !ambiguousCategory) {
      return ChatParseResult.question(
        memory.isActive
            ? AppLocalizations.of(context).translate('financial_secretary_pending_details_prompt')
            : AppLocalizations.of(context).translate('financial_secretary_transaction_prompt'),
      );
    }
    // Freeze the default day on the first accepted turn (including midnight).
    memory.date ??= DateTime.now();
    if (ambiguousCategory || (!metadataOnly && match == null &&
        TransactionActionKeywords.hasPurchase(folded))) memory.categoryKey = null;
    if (!metadataOnly && !ambiguousCategory && match == null &&
        TransactionActionKeywords.hasPurchase(folded)) {
      memory.ambiguousTerm = null;
      memory.categoryCandidates.clear();
    }
    if (ambiguousCategory) {
      memory.categoryCandidates = options.map((e) => e.key).toList();
      memory.ambiguousTerm = !isCategoryReply && analysis.canClarifySingleTerm ? analysis.ambiguousTerms.first : null;
    }
    if (match != null) {
      memory.categoryKey = match.key;
      memory.categoryCandidates.clear();
      memory.ambiguousTerm = null;
    }
    if (amount != null) memory.amount = amount;
    if (parsedDate != null) memory.date = parsedDate;
    if (parsedTime != null) memory.time = parsedTime;
    if (locationUpdate != null) {
      final prefix = RegExp(
        r'^(?:dia diem|location)\s*[:：]?\s*',
      ).firstMatch(_foldKeepingOffsets(text))!;
      memory.location = text.substring(prefix.end).trim();
    } else if (location.isNotEmpty) {
      memory.location = location;
    }
    if (noteUpdate != null) {
      final prefix = RegExp(
        r'^(?:ghi chu|note)\s*[:：]?\s*',
      ).firstMatch(_foldKeepingOffsets(text))!;
      memory.note = text.substring(prefix.end).trim();
      memory.noteIsExplicit = true;
    } else if (!metadataOnly && !isCategoryReply && !memory.noteIsExplicit &&
        (memory.note.isEmpty || TransactionActionKeywords.hasPurchase(folded) || RegExp(r'\b(an|uong|ate|drank|nhan luong|received|sua thanh|change to)\b').hasMatch(folded))) {
      memory.note = _cleanNote(text, context);
      if (RegExp(r'\b(?:ghi chu|note)\s*:').hasMatch(folded)) memory.noteIsExplicit = true;
    }
    // Refine the note only from the user's own clarification text.
    if (!metadataOnly && !isCategoryReply && !memory.noteIsExplicit && pendingTerm != null && match != null &&
        !TransactionActionKeywords.hasPurchase(folded)) {
      final categoryOnly = _fold(categoryLabel(match.key, context)) == folded || match.key == text;
      if (!categoryOnly) {
        final refined = _cleanNote(text, context);
        if (refined.isNotEmpty) {
          memory.note = RegExp('(?<![a-z0-9])$pendingTerm(?![a-z0-9])').hasMatch(_fold(refined))
              ? refined : '${memory.note} $refined'.trim();
        }
      }
    }
    memory.turns.add(text);
    if (memory.turns.length > 20) memory.turns.removeAt(0);
    if (ambiguousCategory) {
      if (!isCategoryReply && analysis.canClarifySingleTerm) {
        return ChatParseResult.question(AppLocalizations.of(context).translate(
            'financial_secretary_clarify_${analysis.ambiguousTerms.first}'));
      }
      final labels = options.take(3).map((e) => categoryLabel(e.key, context)).join(' / ');
      return ChatParseResult.question(AppLocalizations.of(context)
          .translate('financial_secretary_ambiguous_category_prompt')
          .replaceAll('{categories}', labels));
    }
    if (memory.amount == null) {
      final income =
          memory.categoryKey != null && _isIncome(memory.categoryKey!);
      return ChatParseResult.question(
        income
            ? AppLocalizations.of(context).translate('financial_secretary_income_amount_prompt')
            : AppLocalizations.of(context).translate('financial_secretary_expense_amount_prompt'),
      );
    }
    if (memory.categoryKey == null) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_category_for_amount_prompt'),
      );
    }
    final key = memory.categoryKey!;
    final type = listType.indexWhere(
          (item) => item['title'] == key && item['isParent'] != 'true',
    );
    return ChatParseResult.success(
      ChatTransactionDraft(
        amount: memory.amount!,
        type: type,
        typeName: categoryLabel(key, context),
        date: _mergeDateAndTime(memory.date!, memory.time),
        note: memory.note,
        location: memory.location,
        hasExplicitTime: memory.time != null,
        kind: _isIncome(key)
            ? ChatTransactionKind.income
            : ChatTransactionKind.expense,
        confidence: match?.confidence ?? 0.9,
      ),
    );
  }

  static ChatParseResult parse(String raw, BuildContext context) =>
      parseTurn(raw, context, ChatConversationMemory());

  /// Đọc 50k, 50 nghìn, 1.5 triệu, 1,5 triệu, 50.000đ và 50000.
  /// Các số thuộc ngày/giờ sẽ bị bỏ qua, không bị hiểu nhầm là số tiền.
  static double? _amount(String text) {
    text = _foldKeepingOffsets(_categoryText(text));
    text = text.replaceAll(RegExp(r'(?<=\d)đ\b'), ' dong');

    // Exclude complete date/time spans before looking for money. A day,
    // month or minute must never become the amount of a transaction.
    for (final pattern in <RegExp>[
      RegExp(
        r'(?<!\d)(?:ngay\s*)?\d{1,2}\s*[/-]\s*\d{1,2}(?:\s*[/-]\s*\d{2,4})?(?!\d)',
      ),
      RegExp(
        r'(?<![a-z0-9])(?:ngay\s*)?\d{1,2}\s*thang\s*\d{1,2}(?:\s*nam\s*\d{2,4})?(?!\d)',
      ),
      RegExp(r'(?<![a-z0-9])ngay\s*\d{1,2}(?!\d)'),
      _timePattern,
      RegExp(
        r'(?<![a-z0-9])\d{1,2}\s+(?:sang|trua|chieu|toi|am|pm)(?![a-z0-9])',
      ),
    ]) {
      text = _without(text, pattern);
    }
    final pattern = RegExp(
      r'\d[\d.,]*(?:\s*(?:triệu|trieu|tr|million|k|nghìn|nghin|ngàn|ngan|vnd|dong|đ|d)(?![A-Za-zÀ-ỹĐđ0-9]))?',
      caseSensitive: false,
    );

    double? bestAmount;
    var bestScore = -1.0;

    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0)!.trim();
      if (_isDateOrTimeNumber(text, match.start, match.end, raw)) continue;

      final unitMatch = RegExp(
        r'(triệu|trieu|tr|million|k|nghìn|nghin|ngàn|ngan|vnd|dong|đ|d)\s*$',
        caseSensitive: false,
      ).firstMatch(raw);
      final unit = (unitMatch?.group(1) ?? '').toLowerCase();
      var number = unitMatch == null
          ? raw
          : raw.substring(0, unitMatch.start).trim();
      final value = _parseNumber(number);
      if (value == null || !value.isFinite || value <= 0 || value > 9000000000000) continue;

      var amount = value;
      if (unit == 'triệu' || unit == 'trieu' || unit == 'tr' || unit == 'million') {
        amount = value * 1000000;
      } else if (unit == 'k' || unit == 'nghìn' || unit == 'nghin' || unit == 'ngàn' || unit == 'ngan') {
        amount = value * 1000;
      }

      final prefixStart = (match.start - 36).clamp(0, match.start).toInt();
      final prefix = text.substring(prefixStart, match.start).toLowerCase();
      final hasPaymentMarker = RegExp(
        r'(hết|het|tốn|ton|thanh toán|thanh toan|mất|mat|giá|gia|chi|trả|tra|cost|paid|spent)\s*$',
        caseSensitive: false,
      ).hasMatch(prefix);

      // Có đơn vị (k, nghìn, triệu, đ) hoặc đứng sau động từ thanh toán
      // thì gần như chắc chắn đây là số tiền.
      final standalone = RegExp(r'^\s*\d[\d.,]*\s*$').hasMatch(text);
      // Bare model numbers, quantities and addresses are not payment amounts.
      if (unit.isEmpty && !hasPaymentMarker && !standalone &&
          !(value >= 10000 && match.end == text.trimRight().length)) continue;
      var score = unit.isNotEmpty ? 3.0 : 0.5;
      if (hasPaymentMarker) score += 4.0;
      if (amount >= 1000) score += 0.5;

      if (score > bestScore) {
        bestScore = score;
        bestAmount = amount;
      }
    }
    return bestAmount;
  }

  static double? _parseNumber(String raw) {
    var value = raw.replaceAll(' ', '');
    if (value.contains('.') && value.contains(',')) {
      // 1.234,56 hoặc 1,234.56
      if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (value.contains('.') || value.contains(',')) {
      final separator = value.contains('.') ? '.' : ',';
      final parts = value.split(separator);
      value = parts.length > 2 || (parts.length == 2 && parts[1].length == 3)
          ? value.replaceAll(separator, '')
          : value.replaceAll(separator, '.');
    }
    return double.tryParse(value);
  }

  static bool _isDateOrTimeNumber(
      String text,
      int start,
      int end,
      String candidate,
      ) {
    final value = _fold(candidate.trim());

    // Có đơn vị tiền rõ ràng thì không xem là ngày hoặc giờ.
    // Ví dụ: 12tr, 50k, 50000đ.
    if (RegExp(
      r'\d\s*(trieu|tr|million|k|nghin|ngan|đ|d|dong)$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return false;
    }

    final left = _fold(text.substring(0, start));
    final right = _fold(text.substring(end));

    // Các số trong ngày: 16/08/2026 hoặc 16-08-2026.
    if (RegExp(r'[/\-:]$').hasMatch(left) ||
        RegExp(r'^[/\-:]').hasMatch(right)) {
      return true;
    }

    // Số giờ: 5h, 5h30, 5 giờ, 5 am, 5 pm.
    if (RegExp(r'^(?:h(?=\d|\s|$)|gio\b|am\b|pm\b)').hasMatch(right)) {
      return true;
    }

    if (RegExp(r'(?:^|\s)\d{1,2}\s*(?:h|gio)$').hasMatch(left)) {
      return true;
    }

    // Ngày 16 tháng 8 năm 2026.
    if (RegExp(r'(?:^|\s)(?:ngay|thang|nam)$').hasMatch(left)) {
      return true;
    }

    if (RegExp(r'^(?:thang|nam)(?:\s|$)').hasMatch(right)) {
      return true;
    }

    return false;
  }

  static bool _isIncome(String category) => listType.any(
        (item) => item['title'] == category && item['type'] == 'income',
  );

  /// Nhận hôm nay, hôm qua, ngày mai, ngày kia, thứ trong tuần,
  /// dd/MM/yyyy, dd tháng MM năm yyyy và "ngày dd tháng MM".
  static DateTime? _date(String text) {
    final now = DateTime.now();
    final folded = _fold(text);
    if (RegExp(r'\b(hôm nay|hom nay|today)\b').hasMatch(folded)) {
      return DateTime(now.year, now.month, now.day);
    }
    if (RegExp(r'\b(hôm qua|hom qua|yesterday)\b').hasMatch(folded)) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (RegExp(r'\b(ngày mai|ngay mai|tomorrow)\b').hasMatch(folded)) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (RegExp(
      r'\b(ngày kia|ngay kia|day after tomorrow)\b',
    ).hasMatch(folded)) {
      return DateTime(now.year, now.month, now.day + 2);
    }

    var match = RegExp(
      r'\b(\d{1,2})\s*[/-]\s*(\d{1,2})(?:\s*[/-]\s*(\d{2,4}))?\b',
    ).firstMatch(folded);
    if (match != null) {
      return _validDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        _year(match.group(3), now.year),
      );
    }

    match = RegExp(
      r'\b(?:ngày|ngay)\s*(\d{1,2})(?:\s*(?:tháng|thang)\s*(\d{1,2}))?(?:\s*(?:năm|nam)\s*(\d{2,4}))?\b',
    ).firstMatch(folded);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.tryParse(match.group(2) ?? '') ?? now.month;
      return _validDate(day, month, _year(match.group(3), now.year));
    }

    match = RegExp(
      r'\b(\d{1,2})\s*(?:tháng|thang)\s*(\d{1,2})(?:\s*(?:năm|nam)\s*(\d{2,4}))?\b',
    ).firstMatch(folded);
    if (match != null) {
      return _validDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        _year(match.group(3), now.year),
      );
    }

    final monthNames = <String, int>{
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
      'thang mot': 1,
      'thang hai': 2,
      'thang ba': 3,
      'thang tu': 4,
      'thang nam': 5,
      'thang sau': 6,
      'thang bay': 7,
      'thang tam': 8,
      'thang chin': 9,
      'thang muoi': 10,
      'thang muoi mot': 11,
      'thang muoi hai': 12,
    };
    for (final entry in monthNames.entries) {
      final monthMatch = RegExp(
        r'\b(\d{1,2})\s+' + RegExp.escape(entry.key) + r'\s*(\d{2,4})?\b',
      ).firstMatch(folded);
      if (monthMatch != null) {
        return _validDate(
          int.parse(monthMatch.group(1)!),
          entry.value,
          _year(monthMatch.group(2), now.year),
        );
      }
    }
    return null;
  }

  static DateTime? _validDate(int day, int month, int year) {
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static int _year(String? value, int fallback) {
    if (value == null || value.isEmpty) return fallback;
    final year = int.tryParse(value);
    if (year == null) return fallback;
    return year < 100 ? year + 2000 : year;
  }

  // Match complete time tokens, including the minute suffix in 7h30p.
  static final RegExp _timePattern = RegExp(
    r'(?<![\d/.-])(\d{1,2})\s*(?::|h|gio)\s*(\d{1,2})?\s*(?:phut|p)?\s*(sang|trua|chieu|toi|am|pm)?(?![a-z0-9])',
  );

  static DateTime? _time(String text) {
    final folded = _fold(text);
    final match =
        _timePattern.firstMatch(folded) ??
            RegExp(
              r'(?<![\d/.-])(\d{1,2})\s+(sang|trua|chieu|toi|am|pm)(?![a-z0-9])',
            ).firstMatch(folded);
    if (match == null) return null;
    final hasSeparator = match.groupCount == 3;
    var hour = int.parse(match.group(1)!);
    final minute = hasSeparator ? int.tryParse(match.group(2) ?? '0') ?? 0 : 0;
    final marker = (hasSeparator ? match.group(3) : match.group(2)) ?? '';
    if (marker.isNotEmpty && (hour < 1 || hour > 12)) return null;
    if (marker == 'chieu' || marker == 'toi' || marker == 'pm') {
      if (hour < 12) hour += 12;
    } else if (marker == 'sang' || marker == 'am') {
      if (hour == 12) hour = 0;
    } else if (marker == 'trua' && hour < 11) {
      hour += 12;
    }
    if (hour > 23 || minute > 59) return null;
    return DateTime(2000, 1, 1, hour, minute);
  }

  static DateTime _mergeDateAndTime(DateTime date, DateTime? time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  }

  // Location extraction must inspect original spelling before accent folding.
  static List<int>? _locationSpan(String text) =>
      TransactionLocationParser.findSpan(text, _foldKeepingOffsets(text));

  static String _location(String text) {
    final span = _locationSpan(text);
    return span == null ? '' : _tidyNote(text.substring(span[1], span[2]));
  }

  static String _categoryText(String text) {
    final span = _locationSpan(text);
    if (span != null) text = text.replaceRange(span[0], span[2], ' ');
    final explicit = RegExp(r'\b(?:ghi chu|note)\s*:').firstMatch(_foldKeepingOffsets(text));
    if (explicit != null) text = text.substring(0, explicit.start);
    return text;
  }

  static bool _hasMultipleAmounts(String text) {
    final money = RegExp(r'\d[\d.,]*\s*(?:trieu|tr|million|k|nghin|ngan|dong|vnd|d)(?![a-z0-9])');
    final clean = _fold(_categoryText(text));
    final explicit = money.allMatches(clean).toList();
    final bareLarge = RegExp(r'(?<![a-z0-9])\d{5,}(?![a-z0-9])').allMatches(clean)
        .where((m) => !explicit.any((e) => m.start >= e.start && m.end <= e.end));
    return explicit.length + bareLarge.length > 1;
  }

  // Fold accents without changing offsets so removals preserve the original
  // spelling of arbitrary dishes/items, rather than selecting from a food list.
  static String _foldKeepingOffsets(String value) =>
      _fold(value, preserveOffsets: true);

  static String _without(String text, RegExp pattern) {
    final folded = _foldKeepingOffsets(text);
    final matches = pattern.allMatches(folded).toList();
    var result = text;
    for (final match in matches.reversed) {
      result = result.replaceRange(match.start, match.end, ' ');
    }
    return result;
  }

  static String _cleanNote(String text, BuildContext context) {
    final explicit = RegExp(
      r'(?:ghi chu|note)\s*[:：]\s*(.+)$',
    ).firstMatch(_foldKeepingOffsets(text));
    if (explicit != null) {
      return _tidyNote(
        text.substring(
          explicit.start + explicit.group(0)!.indexOf(explicit.group(1)!),
        ),
      );
    }
    var note = _categoryText(text);
    note = _without(note, RegExp(
        r'^\s*(?:ghi giup toi khoan|ghi lai giup minh|ghi khoan nay nhe|them giao dich|them khoan|luu giup toi|ghi lai khoan|cho toi ghi khoan|nho ghi giup khoan|record this|please record that|please add this transaction|add a transaction|please save this|log this transaction|add this|log this|could you record this|please log a transaction)\s*[:：]?\s*'));
    note = _without(note, RegExp(
        r'[,;]?\s*(?:nhe|ghi lai giup toi|please record it|please save it)\s*$'));

    final amount = _amount(text);
    if (amount != null) {
      final bare = RegExp(r'\d[\d.,]*\s*$').firstMatch(note);
      if (bare != null && _parseNumber(bare.group(0)!.trim()) == amount) {
        note = note.substring(0, bare.start);
      }
    }
    note = _without(note, RegExp(
        r'(?<![a-z0-9])(?:sang nay|trua nay|chieu nay|toi nay|this morning|this afternoon|this evening)(?![a-z0-9])'));
    // Remove full date/time spans BEFORE amounts.
    for (final pattern in <RegExp>[
      RegExp(
        r'(?<!\d)(?:ngay\s*)?\d{1,2}\s*[/-]\s*\d{1,2}(?:\s*[/-]\s*\d{2,4})?(?!\d)',
      ),
      RegExp(
        r'(?<![a-z0-9])(?:ngay\s*)?\d{1,2}\s*thang\s*\d{1,2}(?:\s*nam\s*\d{2,4})?(?!\d)',
      ),
      RegExp(r'(?<![a-z0-9])ngay\s*\d{1,2}(?!\d)'),
      _timePattern,
      RegExp(
        r'(?<![a-z0-9])\d{1,2}\s+(?:sang|trua|chieu|toi|am|pm)(?![a-z0-9])',
      ),
      RegExp(
        r'(?<![a-z0-9])(?:hom nay|hom qua|ngay mai|ngay kia|today|yesterday|tomorrow)(?![a-z0-9])',
      ),
      RegExp(
        r'\d[\d.,]*\s*(?:trieu|tr|million|k|nghin|ngan|dong|vnd|d)(?![a-z0-9])',
      ),
      RegExp(r'(?<![a-z0-9])(?:het|ton|gia|cost|paid|spent|for|of|thanh toan)\s+\d[\d.,]*'),
    ]) {
      note = _without(note, pattern);
    }

    note = note.replaceAll('/', ' ');
    // Strip conversational/action prefixes only; do not delete words inside
    // item names (for example "bánh mì", "bún bò", "cơm chiên").
    final prefix = TransactionActionKeywords.leading;
    while (true) {
      final foldedNote = _foldKeepingOffsets(note);
      if (TransactionActionKeywords.shoppingPrefixPattern.hasMatch(foldedNote)) {
        note = _without(note, TransactionActionKeywords.shoppingPrefixPattern);
      } else if (prefix.hasMatch(foldedNote)) {
        note = _without(note, prefix);
      } else {
        break;
      }
    }
    note = _without(note, RegExp(
        r'\s+(?:het|ton|gia|cost|paid|spent|luc|vao|on|at|for|of|dong)\s*$'));
    note = note.replaceAll('/', ' ');
    note = _tidyNote(note);
    if (RegExp(r'^(?:sang|trua|toi|khuya)$').hasMatch(_fold(note))) {
      return AppLocalizations.of(context).translate('financial_secretary_meal_note').replaceAll('{meal}', note);
    }
    return note;
  }

  static String _tidyNote(String value) => value
      .replaceAll(RegExp(r'^[\s,.;:/\-–—]+|[\s,.;:/\-–—]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _fold(String value, {bool preserveOffsets = false}) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    if (preserveOffsets) return result;
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

}
