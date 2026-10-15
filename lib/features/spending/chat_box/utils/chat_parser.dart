import 'package:flutter/widgets.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/core/constants/list.dart';

import 'category_matcher.dart';
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
    'debt_collection',
    'borrow',
    'loan',
    'pay',
    'pay_interest',
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
    final match = metadataOnly ? null : CategoryMatcher.find(text);
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
    final parsedDate = metadataOnly ? null : _date(text);
    final parsedTime = metadataOnly ? null : _time(text);
    final hasDate = RegExp(
      r'\b\d{1,2}\s*[/.-]\s*\d{1,2}|\bngay\s*\d|\b\d{1,2}\s*thang\s*\d',
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
    final location = _location(text);
    if (match == null &&
        amount == null &&
        parsedDate == null &&
        parsedTime == null &&
        noteUpdate == null &&
        locationUpdate == null &&
        location.isEmpty) {
      return ChatParseResult.question(
        memory.isActive
              ? AppLocalizations.of(context).translate('financial_secretary_pending_details_prompt')
              : AppLocalizations.of(context).translate('financial_secretary_transaction_prompt'),
      );
    }
    // Freeze the default day on the first accepted turn (including midnight).
    memory.date ??= DateTime.now();
    if (match != null) memory.categoryKey = match.key;
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
    } else if (match != null && memory.note.isEmpty) {
      memory.note = _cleanNote(text, context);
    }
    memory.turns.add(text);
    if (memory.turns.length > 20) memory.turns.removeAt(0);
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

  static ChatParseResult parse(String raw, BuildContext context) {
    final text = raw.trim();
    if (text.isEmpty) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_empty_input_prompt'),
      );
    }

    final match = CategoryMatcher.find(text);
    if (match != null &&
        (match.key == 'current_money' || match.key == 'new_group')) {
      return ChatParseResult.question(
        match.key == 'current_money'
              ? AppLocalizations.of(context).translate('financial_secretary_balance_guidance')
              : AppLocalizations.of(context).translate('financial_secretary_custom_category_guidance'),
      );
    }

    final amount = _amount(text);
    if (amount == null || amount <= 0) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_missing_amount_prompt'),
      );
    }

    if (match == null) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_category_prompt'),
      );
    }

    // Re-resolve the index from the application's real list, never reindex it.
    final typeIndex = listType.indexWhere(
      (item) => item['title'] == match.key && item['isParent'] != 'true',
    );
    if (typeIndex < 0 || !_categoryKeys.contains(match.key)) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_category_unavailable'),
      );
    }

    final date = _date(text);
    final time = _time(text);
    final folded = _fold(text);
    final hasDate = RegExp(
      r'\b\d{1,2}\s*[/.-]\s*\d{1,2}|\bngay\s*\d|\b\d{1,2}\s*thang\s*\d',
    ).hasMatch(folded);
    final hasTime =
        _timePattern.hasMatch(folded) ||
        RegExp(r'\b\d{1,2}\s+(?:sang|trua|chieu|toi|am|pm)\b').hasMatch(folded);
    if ((hasDate && date == null) || (hasTime && time == null)) {
      return ChatParseResult.question(
        AppLocalizations.of(context).translate('financial_secretary_invalid_datetime'),
      );
    }

    final confidence =
        (match.confidence +
                (date != null ? 0.02 : 0) +
                (time != null ? 0.02 : 0) +
                0.02)
            .clamp(0.0, 0.99)
            .toDouble();

    return ChatParseResult.success(
      ChatTransactionDraft(
        amount: amount,
        type: typeIndex,
        typeName: categoryLabel(match.key, context),
        date: _mergeDateAndTime(date ?? DateTime.now(), time),
        note: _cleanNote(text, context),
        location: _location(text),
        hasExplicitTime: time != null,
        kind: _isIncome(match.key)
            ? ChatTransactionKind.income
            : ChatTransactionKind.expense,
        confidence: confidence,
      ),
    );
  }

  /// Đọc 50k, 50 nghìn, 1.5 triệu, 1,5 triệu, 50.000đ và 50000.
  /// Các số thuộc ngày/giờ sẽ bị bỏ qua, không bị hiểu nhầm là số tiền.
  static double? _amount(String text) {
    // Exclude complete date/time spans before looking for money. A day,
    // month or minute must never become the amount of a transaction.
    for (final pattern in <RegExp>[
      RegExp(
        r'(?<!\d)(?:ngay\s*)?\d{1,2}\s*[/.-]\s*\d{1,2}(?:\s*[/.-]\s*\d{2,4})?(?!\d)',
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
      r'\d[\d.,]*(?:\s*(?:triệu|tr|million|k|nghìn|ngàn|đ|dong)(?![A-Za-zÀ-ỹĐđ0-9]))?',
      caseSensitive: false,
    );

    double? bestAmount;
    var bestScore = -1.0;

    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0)!.trim();
      if (_isDateOrTimeNumber(text, match.start, match.end, raw)) continue;

      final unitMatch = RegExp(
        r'(triệu|tr|million|k|nghìn|ngàn|đ|dong)\s*$',
        caseSensitive: false,
      ).firstMatch(raw);
      final unit = (unitMatch?.group(1) ?? '').toLowerCase();
      var number = unitMatch == null
          ? raw
          : raw.substring(0, unitMatch.start).trim();
      final value = _parseNumber(number);
      if (value == null || value <= 0) continue;

      var amount = value;
      if (unit == 'triệu' || unit == 'tr' || unit == 'million') {
        amount = value * 1000000;
      } else if (unit == 'k' || unit == 'nghìn' || unit == 'ngàn') {
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
      r'\b(\d{1,2})\s*[/\-.]\s*(\d{1,2})(?:\s*[/\-.]\s*(\d{2,4}))?\b',
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

  static String _location(String text) {
    final match = RegExp(
      r'\b(?:ở|o|tại|tai|at|in)\s+([^,.;]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? '';
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
    var note = text;
    // Remove full date/time spans BEFORE amounts.
    for (final pattern in <RegExp>[
      RegExp(
        r'(?<!\d)(?:ngay\s*)?\d{1,2}\s*[/.-]\s*\d{1,2}(?:\s*[/.-]\s*\d{2,4})?(?!\d)',
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
        r'\d[\d.,]*(?:\s*(?:trieu|tr|million|k|nghin|ngan|dong|d)(?![a-z0-9]))?',
      ),
      RegExp(r'(?<![a-z0-9])(?:o|tai|at|in)\s+[^,.;]+'),
    ]) {
      note = _without(note, pattern);
    }
    note = _without(note, RegExp(r'(?<![a-z0-9])ngay(?![a-z0-9])'));
    note = note.replaceAll('/', ' ');
    // Strip conversational/action prefixes only; do not delete words inside
    // item names (for example "bánh mì", "bún bò", "cơm chiên").
    final prefix = RegExp(
      r'^\s*(?:toi|minh|em|anh|ban|di|da|vua|co|an|uong|mua|dung|chi tieu|chi|tra|thanh toan|nhan|dong|gui)\s+',
    );
    while (prefix.hasMatch(_foldKeepingOffsets(note))) {
      note = _without(note, prefix);
    }
    note = _without(
      note,
      RegExp(
        r'(?<![a-z0-9])(?:het|ton|mat|gia|luc|vao|khi|hoi|ngay)(?![a-z0-9])',
      ),
    );
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
