export 'widget/chat_message.dart';

import 'widget/chat_composer.dart';
import 'widget/chat_saving_status.dart';
import 'widget/chat_welcome.dart';
import 'widget/chat_message_bubble.dart';
import 'widget/chat_message_list.dart';
import 'widget/chat_suggestions.dart';
import 'widget/chat_header.dart';
import 'widget/chat_style.dart';
import 'widget/chat_message.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:intl/intl.dart';

import 'model/chat_intent.dart';
import 'utils/chat_parser.dart';

class ChatBox extends StatefulWidget {
  final Future<void> Function(ChatTransactionDraft draft) onCreateTransaction;

  const ChatBox({super.key, required this.onCreateTransaction});

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];

  final ChatConversationMemory _memory = ChatConversationMemory();
  ChatMessage? _activeDraftMessage;

  bool _sameDraft(ChatTransactionDraft a, ChatTransactionDraft b) =>
      a.amount == b.amount &&
          a.type == b.type &&
          a.date == b.date &&
          a.note == b.note &&
          a.location == b.location &&
          a.kind == b.kind &&
          a.hasExplicitTime == b.hasExplicitTime;

  void _retireDraft() {
    final active = _activeDraftMessage;
    if (active == null) return;
    final index = _messages.indexOf(active);
    if (index >= 0) {
      _messages[index] = ChatMessage(
        text: AppLocalizations.of(context).translate('financial_secretary_draft_retired'),
        fromUser: false,
      );
    }
    _activeDraftMessage = null;
  }

  bool _greetingAdded = false;
  bool _saving = false;

  ChatMessage? _savingMessage;
  Timer? _savingTimer;
  int _dotCount = 1;

  String get _greeting {
    return AppLocalizations.of(context).translate('financial_secretary_greeting');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_greetingAdded) return;
    _greetingAdded = true;

    _messages.add(ChatMessage(text: _greeting, fromUser: false));
  }

  @override
  void dispose() {
    _savingTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _focusInput() {
    if (!mounted || _saving) return;
    _focusNode.requestFocus();
  }

  void _useSuggestion(String value) {
    if (_saving) return;

    _controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);

    _focusInput();
  }

  void _clearChat() {
    if (_saving) return;

    _controller.clear();
    _memory.clear();
    _activeDraftMessage = null;

    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(text: _greeting, fromUser: false));
    });
  }

  void _send() {
    final input = _controller.text.trim();
    if (input.isEmpty || _saving) return;
    _controller.clear();
    if (ChatParser.isSave(input)) {
      setState(() => _messages.add(ChatMessage(text: input, fromUser: true)));
      final active = _activeDraftMessage;
      if (active != null) {
        _confirm(active);
      } else {
        setState(
              () => _messages.add(
            ChatMessage(
              text: AppLocalizations.of(context).translate('financial_secretary_incomplete_transaction'),
              fromUser: false,
            ),
          ),
        );
      }
      _scrollToBottom();
      return;
    }
    setState(() {
      _messages.add(ChatMessage(text: input, fromUser: true));
      if (ChatParser.isCancel(input) || ChatParser.isNewTransaction(input)) {
        _retireDraft();
        _memory.clear();
        _messages.add(
          ChatMessage(
            text: AppLocalizations.of(context).translate('financial_secretary_pending_cleared'),
            fromUser: false,
          ),
        );
        return;
      }
      final result = ChatParser.parseTurn(input, context, _memory);
      if (result.draft != null) {
        final previous = _activeDraftMessage?.draft;
        if (previous != null && _sameDraft(previous, result.draft!)) {
          _messages.add(
            ChatMessage(
              text: AppLocalizations.of(context).translate('financial_secretary_details_unchanged'),
              fromUser: false,
            ),
          );
          return;
        }
        _retireDraft();
        final message = ChatMessage(
          text: AppLocalizations.of(context).translate('financial_secretary_review_prompt'),
          fromUser: false,
          draft: result.draft,
        );
        _activeDraftMessage = message;
        _messages.add(message);
      } else {
        _retireDraft();
        _messages.add(
          ChatMessage(
            text: result.question ?? result.error ?? AppLocalizations.of(context).translate('financial_secretary_parse_failed'),
            fromUser: false,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _cancel(ChatMessage message) {
    if (_saving) return;

    final index = _messages.indexOf(message);
    if (index < 0 || !identical(message, _activeDraftMessage)) return;

    setState(() {
      _memory.clear();
      _activeDraftMessage = null;
      _messages[index] = ChatMessage(
        text: AppLocalizations.of(context).translate('financial_secretary_draft_cancelled'),
        fromUser: false,
      );
    });
  }

  Future<void> _confirm(ChatMessage message) async {
    final draft = message.draft;

    if (_saving ||
        draft == null ||
        !_messages.contains(message) ||
        !identical(message, _activeDraftMessage)) {
      return;
    }

    _focusNode.unfocus();

    setState(() {
      _saving = true;
      _savingMessage = message;
      _dotCount = 1;
    });

    _savingTimer?.cancel();
    _savingTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;

      setState(() {
        _dotCount = _dotCount % 3 + 1;
      });
    });

    try {
      await WidgetsBinding.instance.endOfFrame;

      if (mounted) {
        final messageContext = _savingStatusKey.currentContext;

        if (messageContext != null) {
          Scrollable.ensureVisible(
            messageContext,
            duration: const Duration(milliseconds: 250),
            alignment: 1,
          );
        }
      }

      await widget.onCreateTransaction(draft);

      if (!mounted) return;

      final index = _messages.indexOf(message);

      if (index >= 0) {
        final money = NumberFormat.currency(
          locale: Localizations.localeOf(context).languageCode == 'vi'
              ? 'vi_VN'
              : 'en_US',
          symbol: '₫',
          decimalDigits: 0,
        ).format(draft.amount);

        setState(() {
          _messages[index] = ChatMessage(
            text: AppLocalizations.of(context).translate('financial_secretary_save_success').replaceAll('{amount}', money),
            fromUser: false,
          );
          _memory.clear();
          _activeDraftMessage = null;
          _messages.add(
            ChatMessage(
              text: AppLocalizations.of(context).translate('financial_secretary_next_transaction_prompt'),
              fromUser: false,
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (!mounted) return;
      setState(
            () => _messages.add(
          ChatMessage(
            text: AppLocalizations.of(context).translate('financial_secretary_save_failed_draft_kept'),
            fromUser: false,
          ),
        ),
      );
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppLocalizations.of(context).translate('financial_secretary_save_error')),
        ),
      );
    } finally {
      _savingTimer?.cancel();
      _savingTimer = null;

      if (mounted) {
        setState(() {
          _saving = false;
          _savingMessage = null;
          _dotCount = 1;
        });
      }
    }
  }

  final GlobalKey _savingStatusKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatStyle(context).pageColor,
      appBar: ChatHeader(saving: _saving, hasPendingTransaction: _memory.isActive, onBack: () { Navigator.maybePop(context); }, onClear: _clearChat),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusInput,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              ChatSuggestions(memory: _memory, hasDraft: _activeDraftMessage != null, saving: _saving, onSelected: _useSuggestion),
              Expanded(child: ChatMessageList(
                controller: _scrollController,
                messageCount: _messages.length,
                messageBuilder: (context, index) {
                  final message = _messages[index];
                  return KeyedSubtree(key: ObjectKey(message), child: _buildMessage(message));
                },
              )),
              ChatComposer(controller: _controller, focusNode: _focusNode, saving: _saving, onSend: _send),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    if (_messages.isNotEmpty && identical(message, _messages.first) &&
        !message.fromUser && message.draft == null) {
      return ChatWelcome(greeting: _greeting);
    }
    return ChatMessageBubble(
      message: message,
      saving: _saving,
      isSaving: identical(_savingMessage, message),
      onCancel: () => _cancel(message),
      onConfirm: () => _confirm(message),
      savingStatus: ChatSavingStatus(key: _savingStatusKey, dotCount: _dotCount),
    );
  }
}
