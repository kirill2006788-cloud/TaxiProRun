import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'trip_chat_provider.dart';

class TripChatSheet extends StatefulWidget {
  const TripChatSheet({
    super.key,
    required this.driverName,
    required this.provider,
  });

  final String driverName;
  final TripChatProvider provider;

  @override
  State<TripChatSheet> createState() => _TripChatSheetState();
}

class _TripChatSheetState extends State<TripChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    widget.provider.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(TripChatProvider chat) async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final ok = await chat.send(text);
    if (ok && mounted) {
      _controller.clear();
      _scrollToLatest();
    }
  }

  Future<void> _sendReaction(TripChatProvider chat, String reaction) async {
    final ok = await chat.send(reaction);
    if (ok && mounted) _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.provider,
      child: Consumer<TripChatProvider>(
        builder: (context, chat, _) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Чат с водителем',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  widget.driverName,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (chat.offlineHint)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          chat.error ??
                              'Чат работает локально — сообщения появятся у водителя после подключения к серверу',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Expanded(
                      child: chat.loading
                          ? const Center(child: CircularProgressIndicator())
                          : chat.messages.isEmpty
                              ? Center(
                                  child: Text(
                                    'Напишите водителю',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    8,
                                  ),
                                  itemCount: chat.messages.length,
                                  itemBuilder: (context, index) {
                                    final m = chat.messages[index];
                                    return _Bubble(
                                      message: m,
                                      time: _timeFmt
                                          .format(m.createdAt.toLocal()),
                                    );
                                  },
                                ),
                    ),
                    if (chat.error != null && chat.canSend)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          chat.error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 42,
                      child: Row(
                        children:
                            ['👍', '❤️', '👋', 'Я уже выхожу'].map((item) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ActionChip(
                                label: SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(item),
                                  ),
                                ),
                                onPressed: chat.sending
                                    ? null
                                    : () => _sendReaction(chat, item),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.send,
                              onSubmitted:
                                  chat.sending ? null : (_) => _send(chat),
                              decoration: const InputDecoration(
                                hintText: 'Сообщение…',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: chat.sending || !chat.canSend
                                ? null
                                : () => _send(chat),
                            child: chat.sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.time});

  final TripChatMessage message;
  final String time;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.purple.withValues(alpha: 0.18)
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          border: Border.all(
            color: isMine
                ? AppColors.purple.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'Вы' : 'Водитель',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isMine ? AppColors.purple : AppColors.gold,
              ),
            ),
            const SizedBox(height: 2),
            Text(message.body),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
