import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/trend_chart.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/trend_prediction_row.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class TrendTab extends StatefulWidget {
  final TrendPredictionResult result;
  final bool isDarkMode;
  final Future<void> Function(int days)? onHorizonChanged;
  final Future<TrendPredictionResult> Function(int days)? forecastLoader;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(Map<String, dynamic> action)? onAction;
  final bool isLoading;

  const TrendTab({
    Key? key,
    required this.result,
    required this.isDarkMode,
    this.onHorizonChanged,
    this.forecastLoader,
    this.onRefresh,
    this.onAction,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<TrendTab> createState() => _TrendTabState();
}

class _TrendTabState extends State<TrendTab> {
  late TrendPredictionResult _activeResult;
  bool _inheritedDarkMode = false;

  bool get _darkMode => widget.isDarkMode || _inheritedDarkMode;

  @override
  void initState() {
    super.initState();
    _activeResult = widget.result;
  }

  @override
  void didUpdateWidget(covariant TrendTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      _activeResult = widget.result;
    }
  }
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VI', symbol: '₫', decimalDigits: 0,
  );
  final GlobalKey _timelineKey = GlobalKey();
  final Map<String, GlobalKey> _dayKeys = <String, GlobalKey>{};
  bool _busy = false;
  bool _showHomeLoading = false;
  bool _showAllCards = false;
  int? _selectedDays;

  bool get _loading => widget.isLoading || _busy;
  static const Color _cyan = Color.fromRGBO(0, 210, 255, 1);
  static const Color _teal = Color.fromRGBO(45, 216, 198, 1);
  Color get _text => _darkMode ? Colors.white : Colors.black87;
  Color get _muted => _darkMode ? Colors.white70 : Colors.black54;
  Color get _surface => _darkMode ? const Color(0xFF303030) : Colors.white;
  Color get _background => _darkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
  Color get _accent => _darkMode ? _cyan : const Color(0xFF007F99);
  Color get _secondary => _darkMode ? _teal : const Color(0xFF087F75);
  Color get _positive => _darkMode ? const Color(0xFF65D6B0) : const Color(0xFF087F5B);
  Color get _warning => _darkMode ? const Color(0xFFFFC46B) : const Color(0xFF995500);
  Color get _danger => _darkMode ? const Color(0xFFFF9B8F) : const Color(0xFFB3261E);

  ThemeData get _tabTheme {
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final colors = ColorScheme.fromSeed(seedColor: _teal, brightness: brightness)
        .copyWith(primary: _accent, secondary: _secondary, surface: _surface,
        onSurface: _text, error: _danger);
    final base = ThemeData(brightness: brightness, colorScheme: colors);
    return base.copyWith(
      scaffoldBackgroundColor: _background,
      cardColor: _surface,
      dividerColor: _border,
      disabledColor: _darkMode ? Colors.white38 : Colors.black38,
      textTheme: base.textTheme.apply(bodyColor: _text, displayColor: _text),
      iconTheme: IconThemeData(color: _secondary),
    );
  }
  Color get _border => _darkMode ? Colors.white12 : Colors.black12;

  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((v) => _map(v)).toList();
  }

  String _str(dynamic value, [String fallback = '']) =>
      value == null ? fallback : value.toString();

  num? _number(dynamic value) {
    final num? n = value is num ? value : num.tryParse(_str(value));
    return n != null && n.isFinite ? n : null;
  }

  String _money(dynamic value) {
    final n = _number(value);
    return n == null ? 'Chưa có dữ liệu' : _currency.format(n);
  }

  String _date(dynamic value) {
    // Backend sends local calendar dates. Do not convert them to UTC.
    final date = DateTime.tryParse(_str(value));
    return date == null ? _str(value, '—') : DateFormat('dd/MM/yyyy').format(date);
  }

  String _period(Map<String, dynamic> window) =>
      '${_date(window['start'])} – ${_date(window['end'])}';

  Future<void> _run(Future<void> Function() work, {bool showHomeLoading = false}) async {
    if (_loading) return;
    setState(() {
      _busy = true;
      _showHomeLoading = showHomeLoading;
    });
    try {
      await work();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa thực hiện được. Vui lòng kiểm tra kết nối và thử lại.'),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _showHomeLoading = false;
        });
      }
    }
  }

  bool _canHandle(Map<String, dynamic> action) {
    if (widget.onAction != null) return true;
    if (action['type'] != 'view_timeline') return false;
    final date = _str(_map(action['payload'])['date']);
    return date.isEmpty || _dayKeys.containsKey(date);
  }

  Future<void> _handle(Map<String, dynamic> action) async {
    if (_loading) return;
    if (action['type'] == 'view_timeline') {
      final date = _str(_map(action['payload'])['date']);
      final target = date.isEmpty ? _timelineKey.currentContext : _dayKeys[date]?.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350));
        return;
      }
    }
    if (widget.onAction == null) return;
    const mutations = <String>{
      'mark_paid', 'reschedule_event', 'update_balance', 'edit_budget',
      'confirm_recurring', 'confirm_import', 'review_income_allocation',
    };
    if (action['requiresUserConfirmation'] == true || mutations.contains(action['type'])) {
      setState(() => _busy = true);
      bool? accepted;
      try {
        accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => Theme(
            data: _tabTheme,
            child: AlertDialog(
              title: Text(_str(action['label'], 'Xác nhận thao tác')),
              content: const Text('Tiếp tục mở thao tác này? Kiểm tra thông tin trước khi lưu thay đổi.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tiếp tục')),
              ],
            ),
          ),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted || accepted != true) return;
    }
    await _run(() => widget.onAction!(Map<String, dynamic>.from(action)));
  }

  Widget _body(String text, {Color? color, bool bold = false}) => Text(
    text,
    style: AppStyles.p.copyWith(color: color ?? _muted, height: 1.45,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
  );

  Widget _section(String title, List<Widget> children, {IconData? icon, Key? key}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _darkMode ? Colors.black26 : Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) ...[Icon(icon, color: _secondary, size: 20), const SizedBox(width: 10)],
        Expanded(child: Text(title, style: AppStyles.p.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: _text))),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]),
  );

  Widget _metric(String label, dynamic value, {Color? color}) => Container(
    constraints: const BoxConstraints(minWidth: 130),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 5),
      Text(_money(value), style: TextStyle(color: color ?? _text, fontWeight: FontWeight.w700, fontSize: 16)),
    ]),
  );

  Widget _actionButton(Map<String, dynamic> action) {
    if (action['type'] == 'update_balance' ||
        action['type'] == 'view_category_spending') {
      return const SizedBox.shrink();
    }
    final enabled = _canHandle(action);
    return Tooltip(
      message: enabled ? _str(action['label']) : 'Thao tác này chưa được kết nối trong ứng dụng.',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _secondary,
          side: BorderSide(color: enabled ? _secondary : _border),
          textStyle: AppStyles.p.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _loading || !enabled ? null : () => _handle(action),
        child: Text(_str(action['label'], 'Xem chi tiết')),
      ),
    );
  }

  String _friendlyTitle(dynamic value) {
    final title = _str(value);
    if (RegExp(r'^Lên kế hoạch cho\s+\d+$', caseSensitive: false).hasMatch(title.trim())) {
      return 'Kiểm tra danh mục chưa được đặt tên';
    }
    return title.replaceFirst('Lên kế hoạch cho ', 'Gợi ý chi tiêu: ');
  }

  Future<void> _selectDays(int days) async {
    setState(() => _selectedDays = days);
    if (widget.forecastLoader != null) {
      await _run(() async {
        final loaded = await widget.forecastLoader!(days);
        if (mounted) setState(() => _activeResult = loaded);
      }, showHomeLoading: true);
      return;
    }
    if (widget.onHorizonChanged != null) {
      await _run(() => widget.onHorizonChanged!(days), showHomeLoading: true);
    }
  }

  Map<String, dynamic> _displaySummary() {
    final summary = Map<String, dynamic>.from(_map(_activeResult.summary));
    if (_selectedDays == null) return summary;
    final requested = _selectedDays!;
    final all = _maps(summary['dailyForecastDetail']);
    if (all.isEmpty) {
      if (_activeResult.predictions.length < requested) {
        summary['_windowNotice'] = 'Đã chọn $requested ngày; hiện có ${_activeResult.predictions.length} ngày dự báo. Cần tải thêm dữ liệu để hiển thị đủ.';
      }
      return summary;
    }
    final shown = all.take(requested).toList();
    final available = shown.every((d) => d['forecastAvailable'] != false);
    num income = 0;
    num expense = 0;
    for (final row in shown) {
      income += _number(row['predictedIncome']) ?? 0;
      expense += _number(row['predictedExpense']) ?? 0;
    }
    final dates = shown.map((d) => _str(d['date'])).toSet();
    final window = Map<String, dynamic>.from(_map(summary['forecastWindow']));
    window.addAll({'start': shown.first['date'], 'end': shown.last['date'], 'days': shown.length});
    summary.addAll({
      'forecastWindow': window, 'dailyForecastDetail': shown,
      'dailyForecastCount': shown.length, 'forecastAvailable': available,
      'totalPredictedIncome': income, 'totalPredictedExpense': expense,
      'predictedBalance': income - expense,
    });
    if (shown.length < requested) {
      summary['_windowNotice'] = 'Đã chọn $requested ngày; hiện mới có ${shown.length} ngày dự báo. Cần tải thêm dữ liệu để hiển thị đủ.';
    }
    final advisor = Map<String, dynamic>.from(_map(summary['personalAdvisor']));
    advisor['timeline'] = _maps(advisor['timeline']).where((r) => dates.contains(_str(r['date']))).toList();
    summary['personalAdvisor'] = advisor;
    final months = <Map<String, dynamic>>[];
    for (final original in _maps(summary['monthlyBreakdown'])) {
      final rows = shown.where((r) => r['analysisMonth'] == original['month']).toList();
      if (rows.isEmpty) continue;
      num inc = 0;
      num exp = 0;
      for (final row in rows) {
        inc += _number(row['predictedIncome']) ?? 0;
        exp += _number(row['predictedExpense']) ?? 0;
      }
      months.add({...original, 'start': rows.first['date'], 'end': rows.last['date'],
        'daysInWindow': rows.length,
        'forecastInWindow': {'income': inc, 'expense': exp, 'balance': inc-exp}});
    }
    summary['monthlyBreakdown'] = months;
    return summary;
  }

  Widget _overview(Map<String, dynamic> summary, Map<String, dynamic> advisor) {
    final window = _map(summary['forecastWindow']).isNotEmpty
        ? _map(summary['forecastWindow']) : _map(summary['dailyForecastPeriod']);
    final days = _selectedDays ?? _number(window['days'])?.toInt() ?? _number(summary['dailyForecastCount'])?.toInt() ?? 7;
    final known = summary['forecastAvailable'] != false;
    return _section('Kế hoạch các ngày sắp tới', [
      _body(window['start'] == null ? _str(summary['predictionPeriod'], 'Khoảng dự báo chưa được cung cấp') : _period(window)),
      if (summary['forecastMode'] == 'month')
        _body('Đang xem riêng một tháng. Chuyển sang kế hoạch liên tục để xem cả ngày thuộc tháng sau.'),
      const SizedBox(height: 10),
      Row(children: [
        for (final option in const [7, 14, 30]) Expanded(
          child: Semantics(
            selected: days == option,
            button: true,
            enabled: !_loading,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loading || days == option ? null : () => _selectDays(option),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(
                    color: days == option ? _positive : Colors.transparent,
                    width: 2,
                  ))),
                  child: Text('$option ngày', textAlign: TextAlign.center,
                    style: AppStyles.p.copyWith(
                      color: days == option ? _accent : _secondary,
                      fontSize: 16,
                      fontWeight: days == option ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (summary['_windowNotice'] != null) _body(_str(summary['_windowNotice']), color: _warning),
      if (!known) _body('Chưa đủ lịch sử để dự báo số tiền. Giá trị 0 khi thiếu dữ liệu không có nghĩa là không phát sinh chi.'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metric('Thu ước tính trong khoảng', known ? summary['totalPredictedIncome'] : null),
        _metric('Chi ước tính trong khoảng', known ? summary['totalPredictedExpense'] : null),
        _metric('Chênh lệch thu − chi', known ? summary['predictedBalance'] : null),
      ]),
      const SizedBox(height: 10),
      _body('Thu theo ngày có thể là phân bổ từ tổng tháng. Chênh lệch thu − chi không phải số dư ví.'),
      if (advisor['asOf'] != null) _body('Dữ liệu tính tại: ${_date(advisor['asOf'])}'),
    ], icon: Icons.date_range_outlined);
  }

  Widget _trend(Map<String, dynamic> summary) {
    final trend = _map(summary['trendAnalysis']);
    if (trend.isEmpty) {
      final old = _map(summary['trend']);
      return _section('Phân tích xu hướng', [
        for (final key in ['incomeTrend', 'expenseTrend', 'recommendation'])
          if (_str(old[key]).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: _body(_str(old[key]))),
        if (old.isEmpty) _body('Chưa có phân tích xu hướng.'),
      ], icon: Icons.insights_outlined);
    }
    final current = _map(trend['currentPeriod']);
    final previous = _map(trend['previousPeriod']);
    return _section('Xu hướng và việc cần chú ý', [
      _body(_str(trend['headline']), bold: true, color: _text),
      if (current.isNotEmpty && previous.isNotEmpty) ...[
        const SizedBox(height: 10),
        _body('7 ngày đã kết thúc: ${_period(current)}'),
        _body('So với: ${_period(previous)}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('Chi kỳ gần đây', current['expense']),
          _metric('Chi kỳ trước', previous['expense']),
        ]),
      ],
      for (final signal in _maps(trend['positiveSignals'])) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _body('Điểm tích cực: ${_str(signal['text'])}', color: _positive),
          if (_str(signal['doesNotImply']).isNotEmpty) _body(_str(signal['doesNotImply'])),
        ]),
      ),
      for (final signal in _maps(trend['attentionPoints'])) Padding(
        padding: const EdgeInsets.only(top: 10), child: _body('Cần chú ý: ${_str(signal['text'])}', color: _warning),
      ),
      if (trend['conclusionsSupported'] != true) ...[
        const SizedBox(height: 10),
        _body('Lịch sử chưa được xác nhận đầy đủ; chưa kết luận chi tiêu đã tốt hơn hay xấu đi.'),
      ],
    ], icon: Icons.insights_outlined);
  }

  Widget _cards(Map<String, dynamic> advisor) {
    final cards = _maps(advisor['actionCards']).where((c) => !['missing_balance', 'reduce_spending'].contains(c['type'])).toList();
    final shown = _showAllCards ? cards : cards.take(4).toList();
    return _section('Việc nên làm theo dữ liệu hiện tại', [
      if (cards.isEmpty) _body('Chưa có đề xuất có đủ căn cứ. Cập nhật giao dịch, ngân sách và khoản đến hạn.'),
      for (final card in shown) Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _body(_friendlyTitle(card['title']), bold: true, color: _text),
          if (card['dueDate'] != null) _body('Ngày: ${_date(card['dueDate'])}'),
          _body(_str(card['body'])),
          if (_str(card['reason']).isNotEmpty) _body('Căn cứ: ${_str(card['reason'])}'),
          Wrap(spacing: 8, runSpacing: 4, children: _maps(card['actions']).map(_actionButton).toList()),
        ]),
      ),
      if (cards.length > 4) TextButton(
        onPressed: () => setState(() => _showAllCards = !_showAllCards),
        child: Text(_showAllCards ? 'Thu gọn' : 'Xem tất cả ${cards.length} đề xuất'),
      ),
    ], icon: Icons.lightbulb_outline);
  }

  List<Map<String, dynamic>> _dailyRows(Map<String, dynamic> summary, Map<String, dynamic> advisor) {
    final rows = <String, Map<String, dynamic>>{};
    // Key by date, not index: avoids mismatching suggestions across month boundaries.
    for (final row in _maps(summary['dailyForecastDetail'])) {
      final date = _str(row['date']);
      if (date.isNotEmpty) rows[date] = Map<String, dynamic>.from(row);
    }
    final plans = {for (final row in _maps(advisor['timeline'])) _str(row['date']): row};
    final advice = {for (final row in _maps(summary['spendingRecommendations'])) _str(row['date']): row};
    final suggestions = {for (final row in _maps(summary['dailySuggestions'])) _str(row['date']): row};
    if (summary['forecastMode'] != 'month') {
      for (final date in plans.keys) {
        if (date.isNotEmpty) rows.putIfAbsent(date, () => {'date': date, 'forecastAvailable': false});
      }
    }
    final keys = rows.keys.toList()..sort();
    _dayKeys.removeWhere((key, _) => !rows.containsKey(key));
    return keys.map((date) {
      final row = rows[date]!;
      row['_plan'] = plans[date];
      row['_advice'] = advice[date];
      row['_suggestion'] = suggestions[date];
      _dayKeys.putIfAbsent(date, () => GlobalKey());
      return row;
    }).toList();
  }

  Widget _dailyCard(Map<String, dynamic> row) {
    final date = _str(row['date']);
    final plan = _map(row['_plan']);
    final known = row['forecastAvailable'] != false;
    final ownRecommendations = _maps(row['spendingRecommendations']);
    final recommendations = ownRecommendations.isNotEmpty
        ? ownRecommendations : _maps(_map(row['_advice'])['recommendations']);
    final rawSuggestion = _map(row['_suggestion']).isNotEmpty
        ? _map(row['_suggestion']) : _map(row['suggestion']);
    // Ignore allowance prompts from an older backend too.
    final suggestion = ['daily_plan', 'missing_balance', 'reduce_spending']
        .contains(rawSuggestion['type'])
        ? <String, dynamic>{} : rawSuggestion;
    return _section('${_str(row['weekday'])} ${_date(date)}'.trim(), [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metric('Thu ước tính', known ? row['predictedIncome'] : null),
        _metric('Chi ước tính', known ? row['predictedExpense'] : null),
      ]),
      if (row['incomeIsAllocation'] == true || row['expenseIsAllocation'] == true) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _body('Có giá trị phân bổ từ tổng tháng; không phải lịch nhận/trả tiền đã xác nhận.'),
      ),
      if (_maps(plan['events']).isNotEmpty || (_number(plan['conservativeIntradayBalance']) ?? 0) < 0) ...[
        const Divider(height: 24),
        if ((_number(plan['conservativeIntradayBalance']) ?? 0) < 0) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _body('Có thể thiếu tiền trong ngày trước khi khoản thu về.', color: _danger),
        ),
        for (final event in _maps(plan['events'])) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _body('${_str(event['title'])}: ${_money(event['amount'])}'
              '${event['confirmed'] == true ? '' : ' • Chưa xác nhận'}'
              '${event['overdue'] == true ? ' • Quá hạn' : ''}'),
        ),
      ],
      const Divider(height: 24),
      _body('Đề xuất cho ngày này', bold: true, color: _text),
      if (_str(suggestion['text']).isNotEmpty &&
          !recommendations.any((r) => r['suggestion'] == suggestion['text']))
        _body(_str(suggestion['text'])),
      for (final recommendation in recommendations) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _body(_friendlyTitle(recommendation['title']), bold: true, color: _text),
          _body(_str(recommendation['suggestion'])),
          _body('Vì sao: ${_str(recommendation['reason'], 'Dựa trên dữ liệu được cung cấp.')}'),
          if (_map(recommendation['action']).isNotEmpty) _actionButton(_map(recommendation['action'])),
        ]),
      ),
      if (recommendations.isEmpty && _str(suggestion['text']).isEmpty)
        _body('Chưa có đề xuất mới có đủ căn cứ cho ngày này.'),
    ], key: _dayKeys[date], icon: Icons.event_note_outlined);
  }

  Widget _monthly(Map<String, dynamic> summary) {
    final months = _maps(summary['monthlyBreakdown']);
    return _section('Phân bổ theo tháng', [
      _body('Các số dưới đây chỉ thuộc những ngày nằm trong khoảng dự báo, không phải tổng cả tháng.'),
      for (final month in months) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _body('${_str(month['month'])} • ${_str(month['daysInWindow'])} ngày', bold: true, color: _text),
          _body(_period(month)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _metric('Thu trong khoảng', month['forecastAvailable'] == false ? null : _map(month['forecastInWindow'])['income']),
            _metric('Chi trong khoảng', month['forecastAvailable'] == false ? null : _map(month['forecastInWindow'])['expense']),
          ]),
        ]),
      ),
    ], icon: Icons.calendar_month_outlined);
  }



  Widget _imports(Map<String, dynamic> review) {
    final rows = _maps(review['candidates']);
    return _section('Giao dịch nhập tự động chờ kiểm tra', [
      _body('Dữ liệu từ thông báo hoặc văn bản OCR. Chưa được ghi vào sổ cho đến khi xác nhận.'),
      for (final row in rows) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _body('${_date(row['date'])} • ${_money(row['amount'])}', bold: true, color: _text),
          _body(row['status'] == 'already_imported' ? 'Đã nhập trước đó' : 'Cần kiểm tra nội dung giao dịch'),
          if (row['possibleDuplicate'] == true) _body('Có thể trùng giao dịch đã ghi nhận.', color: _warning),
          if (row['ambiguousAmount'] == true) _body('Có nhiều số tiền cần xác minh.', color: _warning),
          if (row['status'] != 'already_imported') _actionButton({
            'type': 'review_import', 'label': 'Kiểm tra giao dịch',
            'payload': {'candidate': row}, 'requiresUserConfirmation': false,
          }),
        ]),
      ),
    ], icon: Icons.receipt_long_outlined);
  }

  Widget _loadingCard({double height = 112, int lines = 2}) {
    final base = _darkMode ? const Color(0xFF303030) : const Color(0xFFE0E0E0);
    final highlight = _darkMode ? const Color(0xFF4A4A4A) : const Color(0xFFF5F5F5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          height: height,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(height: 14, width: 190, color: Colors.white),
              const SizedBox(height: 8),
              for (int i = 0; i < lines; i++) ...[
                Container(
                  height: 10,
                  width: i == lines - 1 ? 150 : double.infinity,
                  color: Colors.white,
                ),
                if (i != lines - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _trendLoading() {
    return Container(
      color: _background,
      child: Semantics(
        label: 'Đang tải dữ liệu dự báo',
        liveRegion: true,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _loadingCard(height: 156, lines: 3),
            _loadingCard(height: 132, lines: 3),
            _loadingCard(height: 220, lines: 2),
            _loadingCard(height: 112, lines: 2),
            _loadingCard(height: 112, lines: 2),
            _loadingCard(height: 112, lines: 2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _inheritedDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (widget.isLoading || _showHomeLoading) {
      return Theme(data: _tabTheme, child: _trendLoading());
    }
    final summary = _displaySummary();
    final advisor = _map(summary['personalAdvisor']);
    final details = _dailyRows(summary, advisor);
    final warnings = <String>{};
    for (final source in [summary['warnings'], advisor['warnings']]) {
      if (source is List) warnings.addAll(source.map((x) => _str(x)).where((x) => x.isNotEmpty));
    }
    Widget scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_activeResult.success) _section('Chưa tải được dự báo', [
          _body(_activeResult.errorMessage ?? 'Không có dữ liệu'),
          if (widget.onRefresh != null) TextButton.icon(
            onPressed: _loading ? null : () => _run(widget.onRefresh!, showHomeLoading: true),
            icon: const Icon(Icons.refresh), label: const Text('Thử lại'),
          ),
        ]) else ...[
          _overview(summary, advisor),
          _trend(summary),
          if (advisor.isNotEmpty) _cards(advisor),
          if (_activeResult.predictions.isNotEmpty && summary['forecastAvailable'] != false)
            _section('Biểu đồ thu – chi ước tính', [
              TrendChart(predictions: _activeResult.predictions.take(_selectedDays ?? _activeResult.predictions.length).toList(), isDarkMode: _darkMode),
            ], icon: Icons.bar_chart_outlined),
          if (_maps(summary['monthlyBreakdown']).isNotEmpty) _monthly(summary),
          Padding(
            key: _timelineKey, padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text('Chi tiết và gợi ý từng ngày', textAlign: TextAlign.center,
                style: AppStyles.p.copyWith(color: _muted, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (details.isNotEmpty)
            ...details.map(_dailyCard)
          else if (_activeResult.predictions.isNotEmpty)
            _section('Chi tiết dự báo', [
              for (final prediction in _activeResult.predictions.take(_selectedDays ?? _activeResult.predictions.length)) TrendPredictionRow(
                prediction: prediction, isDarkMode: _darkMode, numberFormat: _currency,
              ),
              _body('Chưa có gợi ý chi tiết cho các ngày này.'),
            ])
          else _section('Chưa có ngày dự báo', [_body('Tháng đã kết thúc hoặc chưa có dữ liệu dự báo phù hợp.')]),
          if (_maps(_map(summary['importReview'])['candidates']).isNotEmpty) _imports(_map(summary['importReview'])),
          if (warnings.isNotEmpty) _section('Lưu ý về dữ liệu', [
            for (final warning in warnings) Padding(padding: const EdgeInsets.only(bottom: 8), child: _body(warning)),
          ], icon: Icons.info_outline),
        ],
      ]),
    );
    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(color: _secondary, backgroundColor: _surface, onRefresh: () => _run(widget.onRefresh!, showHomeLoading: true), child: scroll);
    }
    return Theme(data: _tabTheme, child: Container(color: _background, child: scroll));
  }
}
