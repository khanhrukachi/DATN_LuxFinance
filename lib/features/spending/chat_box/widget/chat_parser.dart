import 'package:flutter/widgets.dart';
import 'package:personal_financial_management/core/constants/list.dart';

import 'category_matcher.dart';
import 'chat_intent.dart';

/// Bộ phân tích câu nhập giao dịch dạng tự nhiên.
/// Hỗ trợ số tiền, ngày tương đối/ngày cụ thể, giờ, địa điểm và ghi chú.
class ChatParser {
  // Direction follows LuxFinance's signed-money convention.
  // Borrowing/transfers are cash inflows, not necessarily earned income.
  static const Set<String> _incomeKeys = {
    'debt_collection', 'borrow', 'earn_profit',
    'salary', 'other_income', 'money_transferred_to',
  };

  static const Map<String, List<String>> _categoryLabels = {
    'current_money': ['Số dư hiện tại', 'Current balance'],
    'eating': ['Ăn uống', 'Food and drinks'],
    'move': ['Đi lại', 'Transport'],
    'rent_house': ['Tiền nhà', 'Rent'],
    'water_money': ['Tiền nước', 'Water bill'],
    'telephone_fee': ['Cước điện thoại', 'Phone bill'],
    'electricity_bill': ['Tiền điện', 'Electricity bill'],
    'gas_money': ['Tiền gas', 'Cooking gas'],
    'tv_money': ['Truyền hình', 'Television'],
    'internet_money': ['Internet', 'Internet'],
    'repair_and_decorate_the_house': ['Sửa chữa và trang trí nhà', 'Home repairs and decoration'],
    'vehicle_maintenance': ['Bảo dưỡng xe', 'Vehicle maintenance'],
    'physical_examination': ['Y tế', 'Healthcare'],
    'insurance': ['Bảo hiểm', 'Insurance'],
    'education': ['Giáo dục', 'Education'],
    'housewares': ['Đồ gia dụng', 'Household goods'],
    'personal_belongings': ['Đồ cá nhân', 'Personal belongings'],
    'pet': ['Thú cưng', 'Pets'],
    'family_service': ['Gia đình', 'Family'],
    'other_costs': ['Chi phí khác', 'Other expenses'],
    'sport': ['Thể thao', 'Sports'],
    'beautify': ['Làm đẹp', 'Beauty'],
    'gifts_donations': ['Quà tặng và từ thiện', 'Gifts and donations'],
    'online_services': ['Dịch vụ trực tuyến', 'Online services'],
    'fun_play': ['Giải trí', 'Entertainment'],
    'invest': ['Đầu tư', 'Investments'],
    'debt_collection': ['Thu nợ', 'Debt collection'],
    'borrow': ['Đi vay', 'Borrowing'],
    'loan': ['Cho vay', 'Lending'],
    'pay': ['Trả nợ', 'Debt repayment'],
    'pay_interest': ['Trả lãi', 'Interest paid'],
    'earn_profit': ['Thu lợi nhuận', 'Profit received'],
    'salary': ['Lương', 'Salary'],
    'other_income': ['Thu nhập khác', 'Other income'],
    'money_transferred': ['Chuyển tiền đi', 'Outgoing transfer'],
    'money_transferred_to': ['Chuyển tiền đến', 'Incoming transfer'],
    'new_group': ['Nhóm tùy chỉnh', 'Custom category'],
  };

  static String categoryLabel(String key, BuildContext context) {
    final labels = _categoryLabels[key];
    if (labels == null) return key;
    return labels[Localizations.localeOf(context).languageCode == 'vi' ? 0 : 1];
  }

  static ChatParseResult parse(String raw, BuildContext context) {
    final text = raw.trim();
    if (text.isEmpty) {
      return ChatParseResult.question(_t(
        context,
        'Bạn muốn ghi khoản thu/chi nào?',
        'What income or expense would you like to record?',
      ));
    }

    final match = CategoryMatcher.find(text);
    if (match != null &&
        (match.key == 'current_money' || match.key == 'new_group')) {
      return ChatParseResult.question(_t(
        context,
        match.key == 'current_money'
            ? 'Số dư không phải khoản thu/chi mới. Bạn hãy dùng màn hình quản lý số dư.'
            : 'Nhóm tùy chỉnh cần tên nhóm và loại thu/chi. Bạn hãy chọn nhóm trong màn hình thêm giao dịch.',
        match.key == 'current_money'
            ? 'A balance is not a new transaction. Please use the balance screen.'
            : 'A custom category needs a name and income/expense direction. Please select it on the transaction screen.',
      ));
    }

    final amount = _amount(text);
    if (amount == null || amount <= 0) {
      return ChatParseResult.question(_t(
        context,
        'Mình chưa hiểu rõ giao dịch. Bạn vui lòng mô tả khoản thu/chi để mình hỗ trợ nhé',
        'I do not quite understand the transaction. Could you please describe the income/expense so I can help?',
      ));
    }

    if (match == null) {
      return ChatParseResult.question(_t(
        context,
        'Khoản này thuộc danh mục nào? Ví dụ: ăn uống, đi lại hoặc mua sắm.',
        'Which category is this? For example: eating, transport or shopping.',
      ));
    }

    // Re-resolve the index from the application's real list, never reindex it.
    final typeIndex = listType.indexWhere(
          (item) => item['title'] == match.key && item['image'] != null,
    );
    if (typeIndex < 0 || !_categoryLabels.containsKey(match.key)) {
      return ChatParseResult.question(_t(
        context,
        'Danh mục này chưa được cấu hình. Bạn hãy chọn danh mục trong màn hình thêm giao dịch.',
        'This category is not configured. Please select it on the transaction screen.',
      ));
    }

    final date = _date(text);
    final time = _time(text);
    final confidence = (match.confidence +
        (date != null ? 0.02 : 0) +
        (time != null ? 0.02 : 0) +
        0.02)
        .clamp(0.0, 0.99)
        .toDouble();

    return ChatParseResult.success(ChatTransactionDraft(
      amount: amount,
      type: typeIndex,
      typeName: categoryLabel(match.key, context),
      date: _mergeDateAndTime(date ?? DateTime.now(), time),
      note: _cleanNote(text),
      location: _location(text),
      hasExplicitTime: time != null,
      kind: _isIncome(match.key)
          ? ChatTransactionKind.income
          : ChatTransactionKind.expense,
      confidence: confidence,
    ));
  }

  /// Đọc 50k, 50 nghìn, 1.5 triệu, 1,5 triệu, 50.000đ và 50000.
  /// Các số thuộc ngày/giờ sẽ bị bỏ qua, không bị hiểu nhầm là số tiền.
  static double? _amount(String text) {
    final pattern = RegExp(
      r'\d[\d.,]*(?:\s*(?:triệu|tr|million|k|nghìn|ngàn|đ|dong))?',
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
    if (RegExp(
      r'^(?:h(?=\d|\s|$)|gio\b|am\b|pm\b)',
    ).hasMatch(right)) {
      return true;
    }

    if (RegExp(
      r'(?:^|\s)\d{1,2}\s*(?:h|gio)$',
    ).hasMatch(left)) {
      return true;
    }

    // Ngày 16 tháng 8 năm 2026.
    if (RegExp(
      r'(?:^|\s)(?:ngay|thang|nam)$',
    ).hasMatch(left)) {
      return true;
    }

    if (RegExp(
      r'^(?:thang|nam)(?:\s|$)',
    ).hasMatch(right)) {
      return true;
    }

    return false;
  }

  static bool _isIncome(String category) => _incomeKeys.contains(category);

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
    if (RegExp(r'\b(ngày kia|ngay kia|day after tomorrow)\b').hasMatch(folded)) {
      return DateTime(now.year, now.month, now.day + 2);
    }

    var match = RegExp(
      r'\b(\d{1,2})\s*(?:/|-|\.)\s*(\d{1,2})(?:\s*(?:/|-|\.)\s*(\d{2,4}))?\b',
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
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'thang mot': 1, 'thang hai': 2, 'thang ba': 3, 'thang tu': 4,
      'thang nam': 5, 'thang sau': 6, 'thang bay': 7, 'thang tam': 8,
      'thang chin': 9, 'thang muoi': 10, 'thang muoi mot': 11,
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

  /// Nhận 18:30, 18h30, 18 giờ 30, 6 giờ tối, 6:30 PM.
  static DateTime? _time(String text) {
    final folded = _fold(text);
    final pattern = RegExp(
      r'\b(\d{1,2})(?:\s*(?::|h|giờ)\s*(\d{1,2})?)?\s*(sáng|trưa|chiều|tối|am|pm)?\b',
    );
    RegExpMatch? match;
    for (final candidate in pattern.allMatches(folded)) {
      final raw = candidate.group(0)!;
      if (raw.contains(':') ||
          RegExp(r'(h|giờ|sáng|trưa|chiều|tối|am|pm)')
              .hasMatch(raw)) {
        match = candidate;
        break;
      }
    }
    if (match == null) return null;

    final start = match.start;
    final before = start > 0 ? folded[start - 1] : '';
    if (before == '/' || before == '-' || before == '.') return null;
    final marker = (match.group(3) ?? '').toLowerCase();
    final hasTimeWord = match.group(0)!.contains(':') ||
        RegExp(r'(h|giờ|sáng|trưa|chiều|tối|am|pm)').hasMatch(match.group(0)!);
    if (!hasTimeWord) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (marker == 'chiều' || marker == 'tối' || marker == 'pm') {
      if (hour < 12) hour += 12;
    } else if (marker == 'sáng' || marker == 'am') {
      if (hour == 12) hour = 0;
    } else if (marker == 'trưa' && hour < 11) {
      hour += 12;
    }
    if (hour > 23 || minute > 59) return null;
    return DateTime(0, 1, 1, hour, minute);
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

  static String _cleanNote(String text) {
    final explicit = RegExp(
      r'(?:ghi chú|ghi chu|note)\s*[:：]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (explicit != null) {
      return _tidyNote(explicit.group(1)!);
    }

    var note = text
        .replaceAll(RegExp(
      r'\b\d{1,2}(?::\d{1,2}|\s*h\s*\d{0,2}|\s*giờ\s*\d{0,2})\s*(sáng|trưa|chiều|tối|am|pm)?\b',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(
      r'\d[\d.,]*(?:\s*(triệu|tr|million|k|nghìn|ngàn|đ|dong))?',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(
      r'\b(hôm nay|hôm qua|ngày mai|ngày kia|today|yesterday|tomorrow)\b',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(
      r'\b(?:ngày|ngay)\s*\d{1,2}(?:\s*(?:tháng|thang)\s*\d{1,2})?(?:\s*(?:năm|nam)\s*\d{2,4})?\b',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(r'\b\d{1,2}[/:.-]\d{1,2}(?:[/:.-]\d{2,4})?\b'), '')
        .replaceAll(RegExp(
      r'\b\d{1,2}(?:\s*(?:h|giờ)\s*\d{0,2})?\s*(sáng|trưa|chiều|tối|am|pm)?\b',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(
      r'\b(?:ở|o|tại|tai|at|in)\s+[^,.;]+',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(
      r'\b(tôi|mình|minh|em|anh|chị|chi|bạn|toi|di|đi|đã|da|vừa|vua|nay)\b',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(
      r'\b(ăn|an|uống|uong|mua|dùng|dung|sử dụng|su dung|chi|tiêu|tieu|hết|het|trả|tra|thanh toán|thanh toan|nhận|nhan|đóng|dong|gửi|gui)\b',
      caseSensitive: false,
    ), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _tidyNote(_removeFillerWords(note));
  }

  static String _removeFillerWords(String value) {
    var result = value;
    const fillers = [
      'tôi', 'toi', 'mình', 'minh', 'em', 'anh', 'chị', 'chi', 'bạn',
      'đi', 'di', 'đã', 'da', 'vừa', 'vua', 'lúc', 'luc', 'vào', 'vao',
      'khi', 'hồi', 'hoi', 'hôm nay', 'hom nay', 'hết', 'het',
      'ăn', 'an', 'uống', 'uong', 'mua', 'dùng', 'dung', 'chi',
      'tiêu', 'tieu', 'trả', 'tra', 'thanh toán', 'thanh toan',
      'nhận', 'nhan', 'đóng', 'dong', 'gửi', 'gui','lương', 'luong',
    ];
    for (final filler in fillers) {
      result = result.replaceAll(
        RegExp('(^|\\s)${RegExp.escape(filler)}(?=\\s|\$)', caseSensitive: false),
        ' ',
      );
    }
    return result;
  }

  static String _tidyNote(String value) {
    var note = value
        .replaceAll(RegExp(r'^[,:;\-–—]+|[,:;\-–—]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (note.isEmpty) return '';
    return '${note[0].toUpperCase()}${note.substring(1)}';
  }

  static String _fold(String value) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a', 'â': 'a', 'ầ': 'a',
      'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ă': 'a', 'ằ': 'a', 'ắ': 'a',
      'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e',
      'ẽ': 'e', 'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ò': 'o', 'ó': 'o',
      'ọ': 'o', 'ỏ': 'o', 'õ': 'o', 'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o',
      'ổ': 'o', 'ỗ': 'o', 'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o',
      'ỡ': 'o', 'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u', 'ư': 'u',
      'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u', 'ỳ': 'y', 'ý': 'y',
      'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'đ': 'd',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _t(BuildContext context, String vi, String en) {
    return Localizations.localeOf(context).languageCode == 'vi' ? vi : en;
  }
}


