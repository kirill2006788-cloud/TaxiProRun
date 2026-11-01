import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/app_error_mapper.dart';
import '../../core/api/models/support_models.dart';
import '../../core/api/services/api_services.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_state_widgets.dart';
import 'widgets/profile_widgets.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');
  List<SupportTicketDto> _tickets = const [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 25), (_) => _load(quiet: true));
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
      final list = await api.support.fetchMine();
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!quiet || _tickets.isEmpty) {
          _error = AppErrorMapper.toRussian(e, fallback: 'Не удалось загрузить обращения');
        }
      });
    } finally {
      api.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>(AppRoutes.supportNew);
          if (created == true && mounted) _load();
        },
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Написать'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _tickets.isEmpty) {
      return const LoadingStateView(message: 'Загрузка обращений…');
    }
    if (_error != null && _tickets.isEmpty) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }
    if (_tickets.isEmpty) {
      return ProfileEmptyState(
        icon: Icons.support_agent_rounded,
        title: 'Обращений пока нет',
        subtitle: 'Опишите проблему — ответим в чате обращения',
        actionLabel: 'Создать обращение',
        onAction: () async {
          final created = await context.push<bool>(AppRoutes.supportNew);
          if (created == true && mounted) _load();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final t = _tickets[index];
          return _TicketCard(
            ticket: t,
            dateLabel: _dateFmt.format(t.updatedAt.toLocal()),
            onTap: () async {
              await context.push(AppRoutes.supportDetail(t.id));
              if (mounted) _load(quiet: true);
            },
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.dateLabel,
    required this.onTap,
  });

  final SupportTicketDto ticket;
  final String dateLabel;
  final VoidCallback onTap;

  Color _statusColor() {
    if (ticket.isClosed) return AppColors.textMuted;
    if (ticket.isReplied) return AppColors.success;
    return AppColors.purple;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.softCard(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.forum_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ticket.statusLabelRu,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
