import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:intl/intl.dart';

import 'widget/chat_intent.dart';
import 'widget/chat_parser.dart';
import 'widget/transaction_confirmation_card.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final ChatTransactionDraft? draft;

  const ChatMessage({required this.text, required this.fromUser, this.draft});
}

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

  String _say(String vi, String en) =>
      Localizations.localeOf(context).languageCode == 'vi' ? vi : en;

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
        text: _say(
          'Bản nháp đã được cập nhật hoặc hủy.',
          'Draft updated or cancelled.',
        ),
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

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageColor =>
      _dark ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);

  Color get _cardColor => _dark ? const Color(0xFF172A30) : Colors.white;

  Color get _textColor => _dark ? Colors.white : const Color(0xFF16343C);

  Color get _mutedColor => _dark ? Colors.white60 : const Color(0xFF687386);

  String _t(String key) => AppLocalizations.of(context).translate(key);

  String get _greeting {
    return _t('transaction_chat_01');
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
              text: _say(
                'Chưa có giao dịch đầy đủ để lưu. Bạn bổ sung thông tin nhé.',
                'No complete transaction to save yet. Please add the missing details.',
              ),
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
            text: _say(
              'Đã xóa giao dịch đang nhập. Bạn muốn ghi khoản thu/chi nào tiếp theo?',
              'Pending transaction cleared. What would you like to record next?',
            ),
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
              text: _say(
                'Thông tin không thay đổi. Bạn nhấn Lưu giao dịch hoặc nhập “lưu”; muốn sửa thì nhập số tiền, danh mục, ngày/giờ mới.',
                'Details are unchanged. Tap Save, type save, or enter corrected details.',
              ),
              fromUser: false,
            ),
          );
          return;
        }
        _retireDraft();
        final message = ChatMessage(
          text: _say(
            'Mình đã ghép thông tin. Bạn kiểm tra rồi lưu nhé. Có thể nhập tiếp để sửa số tiền, danh mục hoặc ngày/giờ.',
            'Your details are ready. Review and save, or enter a correction.',
          ),
          fromUser: false,
          draft: result.draft,
        );
        _activeDraftMessage = message;
        _messages.add(message);
      } else {
        _messages.add(
          ChatMessage(
            text: result.question ?? result.error ?? _t('transaction_chat_03'),
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
        text: _t('transaction_chat_04'),
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
      // Đưa dòng trạng thái đang lưu vào vùng nhìn thấy.
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
            text: _t('transaction_chat_05').replaceAll('{amount}', money),
            fromUser: false,
          );
          _memory.clear();
          _activeDraftMessage = null;
          _messages.add(
            ChatMessage(
              text: _say(
                'Hôm nay bạn còn chi tiêu hoặc nhận khoản tiền nào nữa không? Kể mình để ghi tiếp nhé.',
                'Any other expenses or income today? Tell me to record the next transaction.',
              ),
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
            text: _say(
              'Chưa lưu được giao dịch. Mình vẫn giữ bản nháp; bạn kiểm tra kết nối rồi nhấn Lưu hoặc nhập “lưu” để thử lại.',
              'Save failed. Your draft is kept; check your connection and retry Save.',
            ),
            fromUser: false,
          ),
        ),
      );
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_t('transaction_chat_06')),
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
      backgroundColor: _pageColor,
      appBar: _buildAppBar(),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusInput,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildSuggestions(),
              Expanded(child: _buildMessages()),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _pageColor,
      foregroundColor: _textColor,
      titleSpacing: 8,
      title: Row(
        children: [
          _botAvatar(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('transaction_chat_07'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _memory.isActive
                      ? _say(
                          'Đang giữ một giao dịch chưa lưu',
                          'One pending transaction',
                        )
                      : _t('transaction_chat_08'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _t('transaction_chat_09'),
          onPressed: _saving ? null : _clearChat,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  Widget _botAvatar({double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2FF).withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.insights_rounded,
        color: const Color(0xFF073D43),
        size: size * 0.53,
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _memory.isActive
        ? (_activeDraftMessage != null
              ? [
                  _say('Lưu giao dịch', 'Save'),
                  _say('Hủy', 'Cancel'),
                  _say('Giao dịch mới', 'New transaction'),
                ]
              : (_memory.amount == null
                    ? ['50k', '100k', _say('Hủy', 'Cancel')]
                    : [
                        _say('Đi chợ', 'Groceries'),
                        _say('Ăn uống', 'Food'),
                        _say('Lương', 'Salary'),
                      ]))
        : [
            _say('Hôm nay đi chợ lúc 7h30', 'Groceries today at 7:30'),
            _t('transaction_chat_taxi'),
            _t('transaction_chat_salary'),
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: List.generate(suggestions.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == suggestions.length - 1 ? 0 : 8,
            ),
            child: ActionChip(
              onPressed: _saving
                  ? null
                  : () => _useSuggestion(suggestions[index]),
              avatar: Icon(
                index == 2 ? Icons.payments_rounded : Icons.add_circle_outline,
                size: 16,
                color: _dark ? Colors.tealAccent : const Color(0xFF008F7A),
              ),
              label: Text(suggestions[index]),
              labelStyle: TextStyle(color: _textColor, fontSize: 12),
              backgroundColor: _cardColor,
              side: BorderSide(color: _dark ? Colors.white12 : Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];

        return KeyedSubtree(
          key: ObjectKey(message),
          child: _buildMessage(message),
        );
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    if (_messages.isNotEmpty &&
        identical(message, _messages.first) &&
        !message.fromUser &&
        message.draft == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24, top: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _dark
                ? [const Color(0xFF163A46), const Color(0xFF16463F)]
                : [const Color(0xFFE1F7FF), const Color(0xFFDCF9F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFF2DD8C6).withOpacity(.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _botAvatar(size: 54),
            const SizedBox(height: 20),
            Text(
              _t('transaction_chat_07'),
              style: TextStyle(
                color: _textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _greeting,
              textAlign: TextAlign.justify,
              style: TextStyle(color: _mutedColor, height: 1.6),
            ),
          ],
        ),
      );
    }
    final fromUser = message.fromUser;
    final isSavingThisMessage = identical(_savingMessage, message);

    final bubbleColor = fromUser ? const Color(0xFF2DD8C6) : _cardColor;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: fromUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        _t(
                          fromUser
                              ? 'transaction_chat_you'
                              : 'transaction_chat_assistant',
                        ),
                        style: TextStyle(fontSize: 11, color: _mutedColor),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: fromUser ? null : bubbleColor,
                        gradient: fromUser
                            ? const LinearGradient(
                                colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
                              )
                            : null,
                        border: fromUser
                            ? null
                            : Border.all(color: _textColor.withOpacity(.08)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(fromUser ? 20 : 5),
                          bottomRight: Radius.circular(fromUser ? 5 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              _dark ? 0.12 : 0.06,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: fromUser
                              ? const Color(0xFF073D43)
                              : _textColor,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (message.draft != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AbsorbPointer(
                          absorbing: _saving,
                          child: ExcludeFocus(
                            excluding: _saving,
                            child: Opacity(
                              opacity: _saving ? 0.65 : 1,
                              child: TransactionConfirmationCard(
                                draft: message.draft!,
                                onCancel: () => _cancel(message),
                                onConfirm: () => _confirm(message),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSavingThisMessage) _buildSavingStatus(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavingStatus() {
    final color = _dark ? Colors.tealAccent : const Color(0xFF008F7A);

    return Padding(
      key: _savingStatusKey,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Semantics(
        liveRegion: true,
        label: _t('transaction_chat_10'),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _t('transaction_chat_11'),
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  List.filled(_dotCount, '.').join(),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _dark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_saving,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: TextStyle(color: _textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _saving
                      ? _t('transaction_chat_12')
                      : _t('transaction_chat_13'),
                  hintStyle: TextStyle(color: _mutedColor, fontSize: 13),
                  prefixIcon: Icon(Icons.edit_note_rounded, color: _mutedColor),
                  filled: true,
                  fillColor: _pageColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: _dark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFF2DD8C6),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                tooltip: _t('transaction_chat_14'),
                onPressed: _saving ? null : _send,
                color: const Color(0xFF073D43),
                disabledColor: Colors.white54,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
