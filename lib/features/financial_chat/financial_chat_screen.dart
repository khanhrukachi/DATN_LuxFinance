import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/financial_chat/monthly_comparison_chart.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_api.dart';
import 'chat_data_source.dart';

class FinancialChatScreen extends StatefulWidget {
  const FinancialChatScreen({super.key, required this.categoryCatalog,
    this.baseUrl = const String.fromEnvironment('ML_BASE_URL', defaultValue: 'http://10.0.2.2:8000')});
  final String baseUrl;
  final List<Map<String, dynamic>> categoryCatalog;
  @override
  State<FinancialChatScreen> createState() => _FinancialChatScreenState();
}
class _Message {
  const _Message(
      this.text, {
        this.user = false,
        this.errorKey,
        this.warnings = const [],
        this.evidence = const {},
      });

  final String text;
  final bool user;
  final String? errorKey;
  final List<String> warnings;
  final Map<String, dynamic> evidence;
}
class _FinancialChatScreenState extends State<FinancialChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _source = ChatDataSource();
  final _messages = <_Message>[];
  late final ChatApi _api;
  StreamSubscription<User?>? _authChanges;
  String? _uid;
  bool _busy = false;
  bool _checking = false;
  bool _sessionChanged = false;
  String? _retryQuestion;
  static const _cyan = Color(0xFF00D2FF);
  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [_cyan, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _card => _dark ? const Color(0xFF172A30) : Colors.white;
  Color get _background => _dark ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);
  String _t(String key) => AppLocalizations.of(context).translate(key);

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _api = ChatApi(baseUrl: widget.baseUrl);
    _authChanges = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == _uid) return;
      _api.close();
      setState(() {
        _sessionChanged = true;
        _messages.clear();
        _input.clear();
        _retryQuestion = null;
      });
    });
  }
  @override
  void dispose() {
    _authChanges?.cancel();
    _api.close(); _input.dispose(); _scroll.dispose(); super.dispose();
  }
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }
  void _notice(String key) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(_t(key))));
  String _errorKey(Object error) {
    if (error is ChatApiException) return error.key;
    if (error is TimeoutException) return 'chat_timeout';
    if (error is FirebaseException) {
      return error.code == 'permission-denied' ? 'chat_firestore_permission'
          : error.code == 'unavailable' ? 'chat_firestore_unavailable' : 'chat_firestore_error';
    }
    if (error is StateError && error.message.toString().startsWith('chat_')) {
      return error.message.toString();
    }
    return 'chat_unexpected_error';
  }
  Future<void> _checkConnection() async {
    if (_checking || _busy || _sessionChanged) return;
    setState(() => _checking = true);
    try {
      await _api.checkConnection();
      if (mounted && !_sessionChanged) _notice('chat_health_ok');
    } catch (error, stackTrace) {
      debugPrint('CHAT HEALTH ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && !_sessionChanged) _notice(_errorKey(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
  Future<void> _send([String? preset]) async {
    final question = (preset ?? _input.text).trim();
    if (_busy || _sessionChanged || question.isEmpty) return;
    if (question.length > 2000) { _notice('chat_limit'); return; }
    final uid = _uid;
    if (uid == null) { _notice('chat_login'); return; }
    setState(() {
      _busy = true; _retryQuestion = null;
      _messages.add(_Message(question, user: true));
    });
    _input.clear(); _scrollDown();
    var stage = 'firestore';
    try {
      debugPrint('CHAT: Reading user transactions and budgets');
      final snapshot = await _source.load(uid).timeout(const Duration(seconds: 120));
      if (!mounted || _sessionChanged) return;
      stage = 'api';
      debugPrint('CHAT: Calling backend at ${widget.baseUrl}');
      final reply = await _api.ask(
        uid: uid,
        question: question,
        snapshot: snapshot,
        catalog: widget.categoryCatalog,
      );

      if (!mounted || _sessionChanged) return;

      setState(() {
        _messages.add(
          _Message(
            reply.answer,
            warnings: reply.warnings,
            evidence: reply.evidence,
          ),
        );
      });
    } catch (error, stackTrace) {
      debugPrint('CHAT ERROR [$stage]: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || _sessionChanged) return;
      final key = _errorKey(error);
      setState(() {
        _messages.add(_Message('', errorKey: key));
        _retryQuestion = question;
      });
    } finally {
      if (mounted) { setState(() => _busy = false); _scrollDown(); }
    }
  }
  Widget _welcome(ColorScheme colors) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _dark
            ? [const Color(0xFF163A46), const Color(0xFF16463F)]
            : [const Color(0xFFE1F7FF), const Color(0xFFDCF9F1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _teal.withOpacity(.18))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 54, height: 54,
            decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _teal.withOpacity(.22), blurRadius: 18, offset: const Offset(0, 6))]),
            child: const Icon(Icons.insights_rounded, color: Color(0xFF073D43), size: 28)),
          const SizedBox(height: 22),
          Text(_t('chat_welcome_title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700, color: colors.onSurface, height: 1.25)),
          const SizedBox(height: 12),
          Text(_t('chat_welcome'), style: TextStyle(color: colors.onSurface.withOpacity(.68), height: 1.6)),
        ])),
      const SizedBox(height: 26),
      Text(_t('chat_suggestions'), style: TextStyle(fontWeight: FontWeight.w700,
        fontSize: 15, color: colors.onSurface.withOpacity(.75))),
      const SizedBox(height: 14),
      for (final entry in <String, IconData>{
        'chat_q_summary': Icons.account_balance_wallet_outlined,
        'chat_q_budget': Icons.savings_outlined,
        'chat_q_forecast': Icons.trending_up_rounded,
      }.entries)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(
          color: _card, borderRadius: BorderRadius.circular(20),
          child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => _send(_t(entry.key)),
            child: Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal.withOpacity(.16))),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(
                  color: _teal.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
                  child: Icon(entry.value, color: _dark ? _teal : const Color(0xFF14988F), size: 23)),
                const SizedBox(width: 14),
                Expanded(child: Text(_t(entry.key), style: TextStyle(fontSize: 14, height: 1.45,
                  fontWeight: FontWeight.w500, color: colors.onSurface))),
                const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, size: 22,
                  color: _dark ? _teal : const Color(0xFF14988F)),
              ]))))),
    ]);
  }
  Widget _bubble(_Message m, ColorScheme colors) {
    final error = m.errorKey != null;
    final background = error ? colors.errorContainer : m.user ? _teal : _card;
    final foreground = error ? colors.onErrorContainer : m.user ? const Color(0xFF073D43) : colors.onSurface;
    return Padding(padding: const EdgeInsets.only(bottom: 18), child: Align(
      alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .86),
        child: Column(crossAxisAlignment: m.user ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
            child: Text(_t(m.user ? 'chat_you' : 'chat_assistant'), style: TextStyle(fontSize: 11, color: colors.onSurface.withOpacity(.6)))),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: m.user ? null : background, gradient: m.user ? _gradient : null, borderRadius: BorderRadius.circular(20),
              border: m.user ? null : Border.all(color: colors.onSurface.withOpacity(.08))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(error ? _t(m.errorKey!) : m.text.isEmpty ? _t('chat_no_answer') : m.text,
                textAlign: TextAlign.left,
                style: TextStyle(color: foreground, height: 1.55)),
              if (m.warnings.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: foreground.withOpacity(.15))),
                Text(_t('chat_notes'), style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
                for (final warning in m.warnings)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $warning', textAlign: TextAlign.justify, style: TextStyle(color: foreground.withOpacity(.75), fontSize: 12, height: 1.5))),
              ],
              if (!m.user &&
                  m.evidence['current'] is Map &&
                  m.evidence['previous'] is Map) ...[
                const SizedBox(height: 16),
                MonthlyComparisonChart(evidence: m.evidence),
              ],
            ])),
        ]))));
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(backgroundColor: _background, elevation: 0,
        title: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.insights_rounded, color: Color(0xFF073D43), size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('chat_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_t('chat_subtitle'), style: TextStyle(fontSize: 11, color: colors.onSurface.withOpacity(.6))),
        ])), ]), actions: [
        IconButton(tooltip: _t('chat_check_server'),
          onPressed: _checking || _busy || _sessionChanged ? null : _checkConnection,
          icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.wifi_tethering_rounded)),
        IconButton(tooltip: _t('chat_clear'),
          onPressed: _busy || _sessionChanged || _messages.isEmpty ? null : () => setState(() {
            _messages.clear(); _retryQuestion = null;
          }), icon: const Icon(Icons.delete_outline_rounded))]),
      body: _sessionChanged ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_t('chat_session'))))
          : SafeArea(child: Column(children: [
        Expanded(child: _messages.isEmpty ? _welcome(colors) : ListView.builder(
          controller: _scroll, padding: const EdgeInsets.all(16),
          itemCount: _messages.length + (_busy ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < _messages.length) return _bubble(_messages[index], colors);
            return Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _dark ? _teal : const Color(0xFF14988F))),
              const SizedBox(width: 12), Expanded(child: Text(_t('chat_loading'), style: TextStyle(color: colors.onSurface.withOpacity(.7)))),
            ]));
          })),
        if (_retryQuestion != null && !_busy)
          TextButton.icon(onPressed: () => _send(_retryQuestion), icon: const Icon(Icons.refresh), label: Text(_t('chat_retry'))),
        Container(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(color: _card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: _teal.withOpacity(.12))),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: TextField(controller: _input, enabled: !_busy,
                minLines: 1, maxLines: 4, maxLength: 2000,
                decoration: InputDecoration(hintText: _t('chat_hint'), counterText: '',
                  filled: true, fillColor: _background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
                textInputAction: TextInputAction.newline)),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(valueListenable: _input, builder: (context, value, _) {
                final enabled = !_busy && value.text.trim().isNotEmpty;
                return Semantics(label: _t('chat_send'), button: true,
                  child: Tooltip(message: _t('chat_send'), child: Material(
                    color: enabled ? _teal : colors.onSurface.withOpacity(.12), borderRadius: BorderRadius.circular(16),
                    child: InkWell(borderRadius: BorderRadius.circular(16), onTap: enabled ? () => _send() : null,
                      child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_upward_rounded,
                        color: enabled ? const Color(0xFF073D43) : colors.onSurface.withOpacity(.35)))))));
              }),
            ]),
            const SizedBox(height: 8),
            Text(_t('chat_footer'), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: colors.onSurface.withOpacity(.5))),
          ])),
      ])),
    );
  }
}
