import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/app_services.dart';
import '../../../core/api/services/order_chat_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

Future<void> showOrderChatSheet(
  BuildContext context, {
  required String orderId,
  required String peerLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OrderChatSheet(orderId: orderId, peerLabel: peerLabel),
  );
}

class _OrderChatSheet extends StatefulWidget {
  const _OrderChatSheet({required this.orderId, required this.peerLabel});

  final String orderId;
  final String peerLabel;

  @override
  State<_OrderChatSheet> createState() => _OrderChatSheetState();
}

class _OrderChatSheetState extends State<_OrderChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _chat = OrderChatService(AppServices.instance.client);
  List<OrderChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _loading = true;
  bool _sending = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _bindSocket();
  }

  void _bindSocket() {
    final socket = AppServices.instance.socket;
    _sub = socket.onOrderChat.listen((data) {
      if (data['orderId']?.toString() != widget.orderId) return;
      final raw = data['message'];
      final Map<String, dynamic> map;
      if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      } else {
        map = Map<String, dynamic>.from(data);
      }
      final msg = OrderChatMessage.fromJson(map);
      if (msg.id.isEmpty || msg.text.isEmpty) return;
      if (_messages.any((m) => m.id == msg.id)) return;
      if (!mounted) return;
      setState(() => _messages = [..._messages, msg]);
      _scrollToEnd();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hint = null;
    });
    try {
      final list = await _chat.listMessages(widget.orderId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToEnd();
    } catch (_) {
      // Soft-fail: empty history, UI still usable via socket / local.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hint = 'История недоступна — можно писать; доставка при связи с сервером';
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();

    final driverPhone = context.read<AuthProvider>().phone ?? '';
    final optimistic = OrderChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      orderId: widget.orderId,
      senderRole: 'driver',
      senderId: driverPhone,
      text: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() => _messages = [..._messages, optimistic]);
    _scrollToEnd();

    try {
      final socket = AppServices.instance.socket;
      if (socket.isConnected) {
        final ack = await socket.emitOrderChat(
          orderId: widget.orderId,
          text: text,
        );
        if (ack['ok'] == true && ack['message'] is Map) {
          final msg = OrderChatMessage.fromJson(
            Map<String, dynamic>.from(ack['message'] as Map),
          );
          if (!mounted) return;
          setState(() {
            _messages = [
              for (final m in _messages)
                if (m.id != optimistic.id) m,
              if (!_messages.any((m) => m.id == msg.id)) msg,
            ];
          });
          _scrollToEnd();
          return;
        }
      }

      final msg = await _chat.sendMessage(orderId: widget.orderId, text: text);
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id != optimistic.id) m,
          if (!_messages.any((m) => m.id == msg.id)) msg,
        ];
        _hint = null;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hint =
            'Нет связи — сообщение только на этом устройстве';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final driverPhone = context.watch<AuthProvider>().phone ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.scaffold,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Чат с клиентом',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: t.textPrimary,
                              ),
                            ),
                            Text(
                              widget.peerLabel,
                              style: TextStyle(color: t.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (_hint != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _hint!,
                      style: TextStyle(color: AppColors.gold, fontSize: 12),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Напишите клиенту по заказу',
                                style: TextStyle(color: t.textMuted),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                final m = _messages[i];
                                final mine = m.senderRole == 'driver' ||
                                    m.senderId == driverPhone;
                                return Align(
                                  alignment: mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width *
                                              0.78,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? AppColors.purple
                                              .withValues(alpha: 0.22)
                                          : t.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: t.border),
                                    ),
                                    child: Text(
                                      m.text,
                                      style: TextStyle(
                                        color: t.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Сообщение…',
                            filled: true,
                            fillColor: t.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: t.border),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
