import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/app_error_mapper.dart';
import '../../core/api/models/support_models.dart';
import '../../core/api/services/api_services.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_state_widgets.dart';

class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  final _timeFmt = DateFormat('dd.MM HH:mm');
  SupportTicketDto? _ticket;
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = ApiServices();
    try {
      final ticket = await api.support.fetchById(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
        _error = ticket == null ? 'Обращение не найдено' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!quiet || _ticket == null) {
          _error = AppErrorMapper.toRussian(e, fallback: 'Не удалось загрузить переписку');
        }
      });
    } finally {
      api.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ticket?.subject ?? 'Обращение',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(ticket),
    );
  }

  Widget _buildBody(SupportTicketDto? ticket) {
    if (_loading && ticket == null) {
      return const LoadingStateView(message: 'Загрузка переписки…');
    }
    if (_error != null && ticket == null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }
    if (ticket == null) {
      return const ErrorStateView(message: 'Обращение не найдено');
    }

    final messages = ticket.messages.isNotEmpty
        ? ticket.messages
        : [
            SupportMessageDto(
              id: 'seed',
              from: 'user',
              body: ticket.body,
              createdAt: ticket.createdAt,
            ),
          ];

    return Column(
      children: [
        _StatusBar(ticket: ticket),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final m = messages[index];
              return _MessageBubble(
                message: m,
                timeLabel: _timeFmt.format(m.createdAt.toLocal()),
              );
            },
          ),
        ),
        if (ticket.isClosed)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Обращение закрыто. Создайте новое, если нужна помощь.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.ticket});

  final SupportTicketDto ticket;

  @override
  Widget build(BuildContext context) {
    final color = ticket.isClosed
        ? AppColors.textMuted
        : ticket.isReplied
            ? AppColors.success
            : AppColors.purple;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        ticket.statusLabelRu,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.timeLabel,
  });

  final SupportMessageDto message;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.isAdmin;
    final align = isAdmin ? Alignment.centerLeft : Alignment.centerRight;
    final bg = isAdmin
        ? AppColors.backgroundSecondary
        : AppColors.purple.withValues(alpha: 0.16);
    final border = isAdmin
        ? AppColors.border
        : AppColors.purple.withValues(alpha: 0.28);

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAdmin ? 4 : 16),
            bottomRight: Radius.circular(isAdmin ? 16 : 4),
          ),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment:
              isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              isAdmin ? 'Поддержка' : 'Вы',
              style: TextStyle(
                color: isAdmin ? AppColors.gold : AppColors.purple,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.body,
              style: TextStyle(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              timeLabel,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
