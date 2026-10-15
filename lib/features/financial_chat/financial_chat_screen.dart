import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'data/chat_data_source.dart';
import 'models/chat_message.dart';
import 'services/chat_api.dart';
import 'services/chat_api_exception.dart';
import 'widget/chat_amount_input_dialog.dart';
import 'widget/chat_app_bar.dart';
import 'utils/chat_category_label.dart';
import 'widget/chat_category_picker_sheet.dart';
import 'widget/chat_composer.dart';
import 'widget/chat_message_bubble.dart';
import 'widget/chat_retry_button.dart';
import 'widget/chat_thinking_indicator.dart';
import 'widget/chat_welcome.dart';

class FinancialChatScreen extends StatefulWidget {
  const FinancialChatScreen({
    super.key,
    required this.categoryCatalog,
    this.baseUrl = const String.fromEnvironment(
      'ML_BASE_URL',
      defaultValue: 'https://datn-luxfinance.onrender.com',
      // defaultValue: 'http://10.0.2.2:8000',
    ),
  });

  final String baseUrl;
  final List<Map<String, dynamic>> categoryCatalog;

  @override
  State<FinancialChatScreen> createState() => _FinancialChatScreenState();
}

class _FinancialChatScreenState extends State<FinancialChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _source = ChatDataSource();
  final _messages = <ChatMessage>[];
  late final ChatApi _api;
  StreamSubscription<User?>? _authChanges;
  String? _uid;
  bool _busy = false;
  bool _checking = false;
  bool _sessionChanged = false;
  String? _retryQuestion;
  final _confirmedContext = <String, dynamic>{};
  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _api = ChatApi(baseUrl: widget.baseUrl);
    _authChanges = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == _uid) return;
      _api.close();
      _source.clearCache();
      setState(() {
        _sessionChanged = true;
        _messages.clear();
        _input.clear();
        _retryQuestion = null;
        _confirmedContext.clear();
      });
    });
  }

  @override
  void dispose() {
    _authChanges?.cancel();
    _api.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _notice(String key) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate(key))));

  String _errorKey(Object error) {
    if (error is ChatApiException) return error.key;
    if (error is TimeoutException) return 'financial_chat_timeout';
    if (error is FirebaseException) {
      return error.code == 'permission-denied'
          ? 'financial_chat_firestore_permission'
          : error.code == 'unavailable'
          ? 'financial_chat_firestore_unavailable'
          : 'financial_chat_firestore_error';
    }
    if (error is StateError && error.message.toString().startsWith('financial_chat_')) {
      return error.message.toString();
    }
    return 'financial_chat_unexpected_error';
  }

  Future<void> _send([String? preset, bool retry = false]) async {
    final question = (preset ?? _input.text).trim();
    if (_busy || _checking || _sessionChanged || question.isEmpty) return;
    if (question.length > 2000) {
      _notice('financial_chat_question_length_limit');
      return;
    }
    final uid = _uid;
    if (uid == null) {
      _notice('financial_chat_login_required');
      return;
    }
    final history = _messages
        .where((m) => m.user)
        .map((m) => <String, String>{'role': 'user', 'content': m.text})
        .toList();
    if (retry && history.isNotEmpty && history.last['content'] == question) {
      history.removeLast();
    }
    setState(() {
      _busy = true;
      _retryQuestion = null;
      if (!retry) _messages.add(ChatMessage(question, user: true));
      if (retry && _messages.isNotEmpty && _messages.last.errorKey != null) {
        _messages.removeLast();
      }
    });
    _input.clear();
    _scrollDown();
    var stage = 'firestore';
    try {
      debugPrint('CHAT: Reading user transactions and budgets');
      final snapshot = await _source
          .load(uid, forceRefresh: retry)
          .timeout(const Duration(seconds: 120));
      if (!mounted || _sessionChanged) return;
      stage = 'api';
      debugPrint('CHAT: Calling backend at ${widget.baseUrl}');
      final reply = await _api.ask(
        uid: uid,
        question: question,
        snapshot: snapshot,
        catalog: _localizedCatalog(context),
        languageCode: Localizations.localeOf(context).languageCode,
        history: history,
        additionalContext: _confirmedContext,
      );

      if (!mounted || _sessionChanged) return;

      setState(() {
        _messages.add(
          ChatMessage(
            reply.answer,
            warnings: reply.warnings,
            evidence: reply.evidence,
            examples: reply.supportedExamples,
          ),
        );
      });
      if (reply.needsInput.contains('available_balance') ||
          reply.needsInput.contains('rent_amount')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_sessionChanged) {
            _provideAmount(
              question,
              reply.needsInput.contains('available_balance')
                  ? 'available_balance'
                  : 'target_amount',
            );
          }
        });
      }
    } catch (error, stackTrace) {
      debugPrint('CHAT ERROR [$stage]: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || _sessionChanged) return;
      final key = _errorKey(error);
      setState(() {
        _messages.add(ChatMessage('', errorKey: key));
        _retryQuestion = question;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
  }

  Future<void> _provideAmount(String question, String field) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (_) => ChatAmountInputDialog(
        controller: controller,
        field: field,
      ),
    );
    controller.dispose();
    if (!mounted || _sessionChanged || value == null) return;
    _confirmedContext[field] = value;
    await _send(question, true);
    // Target prices apply only to this question, never the next purchase.
    _confirmedContext.remove('target_amount');
  }

  List<Map<String, dynamic>> _localizedCatalog(BuildContext context) => [
    for (final category in widget.categoryCatalog)
      {
        ...category,
        'display_name': chatCategoryLabel(
          context,
          category['title'] ?? category['id'],
          catalog: widget.categoryCatalog,
        ),
      },
  ];

  void _chooseCategory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: const Color(0xFF2DD8C6).withOpacity(.16)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => ChatCategoryPickerSheet(
        categoryCatalog: _localizedCatalog(context),
        onSelect: (name) {
          _input.text = AppLocalizations.of(context).translate('financial_chat_category_question').replaceAll('{name}', name);
          _input.selection = TextSelection.collapsed(offset: _input.text.length);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: ChatAppBar(
        backgroundColor: _background,
        onBack: () { Navigator.maybePop(context); },
        onChooseCategory: _chooseCategory,
        canChooseCategory: !_busy && !_sessionChanged,
        canClear: !_busy && !_sessionChanged && _messages.isNotEmpty,
        onClear: () => setState(() {
          _messages.clear();
          _retryQuestion = null;
          _confirmedContext.clear();
        }),
      ),
      body: _sessionChanged
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AppLocalizations.of(context).translate('financial_chat_session_changed')),
        ),
      )
          : SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? ChatWelcome(onSend: (text) => _send(text))
                  : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return ChatMessageBubble(
                      message: _messages[index],
                      categoryCatalog: _localizedCatalog(context),
                      exampleEnabled: !_busy,
                      onExampleTap: (example) => _send(example),
                    );
                  }
                  return ChatThinkingIndicator(
                    label: AppLocalizations.of(context).translate('financial_chat_analyzing'),
                  );
                },
              ),
            ),
            if (_retryQuestion != null && !_busy)
              ChatRetryButton(
                label: AppLocalizations.of(context).translate('financial_chat_retry'),
                onTap: () => _send(_retryQuestion, true),
              ),
            ChatComposer(
              controller: _input,
              enabled: !_busy,
              canSubmit: !_busy && !_checking && !_sessionChanged,
              onSend: () => _send(),
            ),
          ],
        ),
      ),
    );
  }
}
