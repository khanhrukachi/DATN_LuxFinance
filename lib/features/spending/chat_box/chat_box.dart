import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'widget/chat_intent.dart';
import 'widget/chat_parser.dart';
import 'widget/transaction_confirmation_card.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final ChatTransactionDraft? draft;

  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.draft,
  });
}

class ChatBox extends StatefulWidget {
  final Future<void> Function(ChatTransactionDraft draft)
  onCreateTransaction;

  const ChatBox({
    super.key,
    required this.onCreateTransaction,
  });

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];

  bool _greetingAdded = false;
  bool _saving = false;

  ChatMessage? _savingMessage;
  Timer? _savingTimer;
  int _dotCount = 1;

  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _pageColor =>
      _dark ? const Color(0xFF0F141C) : const Color(0xFFF5F7FB);

  Color get _cardColor =>
      _dark ? const Color(0xFF1B2430) : Colors.white;

  Color get _textColor =>
      _dark ? Colors.white : const Color(0xFF172033);

  Color get _mutedColor =>
      _dark ? Colors.white60 : const Color(0xFF687386);

  String _t(String vi, String en) {
    return Localizations.localeOf(context).languageCode == 'vi'
        ? vi
        : en;
  }

  String get _greeting {
    return _t(
      'Xin chào! Tôi có thể giúp gì cho bạn hôm nay? '
          'Bạn hãy mô tả khoản thu hoặc chi kèm số tiền. '
          'Tôi sẽ hỗ trợ điền thông tin để bạn kiểm tra trước khi lưu.',
      'Hello! How can I help you today? '
          'Describe your income or expense and include the amount. '
          'I’ll help fill in the details for you to review before saving.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_greetingAdded) return;
    _greetingAdded = true;

    _messages.add(
      ChatMessage(
        text: _greeting,
        fromUser: false,
      ),
    );
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
      ..selection = TextSelection.collapsed(
        offset: value.length,
      );

    _focusInput();
  }

  void _clearChat() {
    if (_saving) return;

    _controller.clear();

    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            text: _greeting,
            fromUser: false,
          ),
        );
    });
  }

  void _send() {
    final input = _controller.text.trim();

    if (input.isEmpty || _saving) return;

    final result = ChatParser.parse(input, context);
    _controller.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: input,
          fromUser: true,
        ),
      );

      if (result.draft != null) {
        _messages.add(
          ChatMessage(
            text: _t(
              'Bạn kiểm tra thông tin giao dịch trước khi lưu nhé:',
              'Please review the transaction before saving:',
            ),
            fromUser: false,
            draft: result.draft,
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: result.question ??
                result.error ??
                _t(
                  'Mình chưa hiểu rõ. Bạn mô tả lại khoản thu hoặc chi nhé.',
                  'Please describe the income or expense again.',
                ),
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
    if (index < 0) return;

    setState(() {
      _messages[index] = ChatMessage(
        text: _t('Đã hủy giao dịch.', 'Transaction cancelled.'),
        fromUser: false,
      );
    });
  }

  Future<void> _confirm(ChatMessage message) async {
    final draft = message.draft;

    if (_saving ||
        draft == null ||
        !_messages.contains(message)) {
      return;
    }

    _focusNode.unfocus();

    setState(() {
      _saving = true;
      _savingMessage = message;
      _dotCount = 1;
    });

    _savingTimer?.cancel();
    _savingTimer = Timer.periodic(
      const Duration(milliseconds: 400),
          (_) {
        if (!mounted) return;

        setState(() {
          _dotCount = _dotCount % 3 + 1;
        });
      },
    );

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
          locale:
          Localizations.localeOf(context).languageCode == 'vi'
              ? 'vi_VN'
              : 'en_US',
          symbol: '₫',
          decimalDigits: 0,
        ).format(draft.amount);

        setState(() {
          _messages[index] = ChatMessage(
            text: _t(
              'Đã lưu giao dịch $money.',
              'Transaction saved: $money.',
            ),
            fromUser: false,
          );
        });
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _t(
              'Chưa thể xác nhận lưu thành công. '
                  'Bạn hãy kiểm tra lịch sử giao dịch trước khi thử lại.',
              'Could not confirm the save. '
                  'Please check your transaction history before retrying.',
            ),
          ),
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
        child: Column(
          children: [
            _buildSuggestions(),
            Expanded(
              child: _buildMessages(),
            ),
            _buildComposer(),
          ],
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
                  _t('Trợ lý tài chính', 'Finance assistant'),
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
                  _t(
                    'Hỗ trợ ghi chép thu chi',
                    'Income and expense assistant',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _mutedColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _t('Làm mới đoạn chat', 'Clear chat'),
          onPressed: _saving ? null : _clearChat,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _botAvatar({double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00BFA6),
            Color(0xFF1976D2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA6).withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
        size: size * 0.53,
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions =
    Localizations.localeOf(context).languageCode == 'vi'
        ? ['Ăn sáng 50k', 'Đi taxi 35k', 'Lương 12 triệu']
        : ['Breakfast 50k', 'Taxi 35k', 'Salary 12 million'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: List.generate(
          suggestions.length,
              (index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index == suggestions.length - 1 ? 0 : 8,
              ),
              child: ActionChip(
                onPressed: _saving
                    ? null
                    : () => _useSuggestion(suggestions[index]),
                avatar: Icon(
                  index == 2
                      ? Icons.payments_rounded
                      : Icons.add_circle_outline,
                  size: 16,
                  color: _dark
                      ? Colors.tealAccent
                      : const Color(0xFF008F7A),
                ),
                label: Text(suggestions[index]),
                labelStyle: TextStyle(
                  color: _textColor,
                  fontSize: 12,
                ),
                backgroundColor: _cardColor,
                side: BorderSide(
                  color: _dark ? Colors.white12 : Colors.black12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior:
      ScrollViewKeyboardDismissBehavior.onDrag,
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
    final fromUser = message.fromUser;
    final isSavingThisMessage =
    identical(_savingMessage, message);

    final bubbleColor =
    fromUser ? const Color(0xFF147DCE) : _cardColor;

    return Align(
      alignment:
      fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!fromUser) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _botAvatar(size: 28),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: fromUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(
                            fromUser ? 20 : 5,
                          ),
                          bottomRight: Radius.circular(
                            fromUser ? 5 : 20,
                          ),
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
                              ? Colors.white
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
                      if (isSavingThisMessage)
                        _buildSavingStatus(),
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
    final color = _dark
        ? Colors.tealAccent
        : const Color(0xFF008F7A);

    return Padding(
      key: _savingStatusKey,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Semantics(
        liveRegion: true,
        label: _t(
          'Đang lưu giao dịch',
          'Saving transaction',
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _t(
                    'Đang lưu giao dịch',
                    'Saving transaction',
                  ),
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
          color: _pageColor,
          border: Border(
            top: BorderSide(
              color: _dark ? Colors.white10 : Colors.black12,
            ),
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
                style: TextStyle(
                  color: _textColor,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _saving
                      ? _t('Đang lưu...', 'Saving...')
                      : _t(
                    'Nhập khoản thu hoặc chi...',
                    'Type an income or expense...',
                  ),
                  hintStyle: TextStyle(
                    color: _mutedColor,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: _mutedColor,
                  ),
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(
                      color:
                      _dark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(
                      color: Color(0xFF00A890),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00BFA6),
                    Color(0xFF1976D2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                tooltip: _t('Gửi', 'Send'),
                onPressed: _saving ? null : _send,
                color: Colors.white,
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