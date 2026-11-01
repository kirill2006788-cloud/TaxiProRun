import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/app_services.dart';
import '../../core/api/services/support_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/support_ticket.dart';
import '../../shared/widgets.dart';

SupportService get _support => AppServices.instance.support;

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');
  List<SupportTicket> _tickets = const [];
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
    try {
      final list = await _support.fetchMine();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Icon(Icons.phone_rounded, color: AppColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Служба поддержки · 08:00–23:00',
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: '+79060424241');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: const Text('Позвонить'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildList(t)),
        ],
      ),
    );
  }

  Widget _buildList(AppTokens t) {
    if (_loading && _tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _tickets.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить',
        subtitle: _error!,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Повторить'),
        ),
      );
    }
    if (_tickets.isEmpty) {
      return EmptyState(
        icon: Icons.support_agent_rounded,
        title: 'Обращений пока нет',
        subtitle: 'Опишите проблему — ответим в чате обращения',
        action: FilledButton.icon(
          onPressed: () async {
            final created = await context.push<bool>(AppRoutes.supportNew);
            if (created == true && mounted) _load();
          },
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Создать обращение'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          final color = ticket.isClosed
              ? t.textMuted
              : ticket.isReplied
                  ? AppColors.success
                  : AppColors.purple;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await context.push(AppRoutes.supportDetail(ticket.id));
                if (mounted) _load(quiet: true);
              },
              child: SectionCard(
                margin: EdgeInsets.zero,
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
                            style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                ticket.statusLabelRu,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _dateFmt.format(ticket.updatedAt.toLocal()),
                                style: TextStyle(color: t.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.textMuted),
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

class SupportCreateScreen extends StatefulWidget {
  const SupportCreateScreen({super.key});

  @override
  State<SupportCreateScreen> createState() => _SupportCreateScreenState();
}

class _SupportCreateScreenState extends State<SupportCreateScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      showDriverSnackBar(context, 'Заполните тему и текст обращения', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _support.createTicket(subject: subject, body: body);
      if (!mounted) return;
      showDriverSnackBar(context, 'Обращение отправлено');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      showDriverSnackBar(
        context,
        AppErrorMapper.toRussian(e, fallback: 'Не удалось отправить обращение'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Новое обращение')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Опишите ситуацию — служба поддержки ответит в переписке.',
            style: TextStyle(color: t.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _subjectCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Тема',
                    prefixIcon: Icon(Icons.subject_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Сообщение',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: Text(_sending ? 'Отправка…' : 'Отправить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  final _timeFmt = DateFormat('dd.MM HH:mm');
  SupportTicket? _ticket;
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
    try {
      final ticket = await _support.fetchById(widget.ticketId);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ticket?.subject ?? 'Обращение',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(ticket, t),
    );
  }

  Widget _buildBody(SupportTicket? ticket, AppTokens t) {
    if (_loading && ticket == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && ticket == null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Ошибка',
        subtitle: _error!,
        action: FilledButton(onPressed: _load, child: const Text('Повторить')),
      );
    }
    if (ticket == null) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Не найдено',
        subtitle: 'Обращение не найдено',
      );
    }

    final messages = ticket.messages.isNotEmpty
        ? ticket.messages
        : [
            SupportMessage(
              id: 'seed',
              from: 'user',
              body: ticket.body,
              createdAt: ticket.createdAt,
            ),
          ];

    final statusColor = ticket.isClosed
        ? t.textMuted
        : ticket.isReplied
            ? AppColors.success
            : AppColors.purple;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: statusColor.withValues(alpha: 0.1),
          child: Text(
            ticket.statusLabelRu,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final m = messages[index];
              final isAdmin = m.isAdmin;
              return Align(
                alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? t.surface
                        : AppColors.purple.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAdmin ? 4 : 16),
                      bottomRight: Radius.circular(isAdmin ? 16 : 4),
                    ),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    crossAxisAlignment: isAdmin
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
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
                      Text(m.body, style: TextStyle(color: t.textPrimary, height: 1.35)),
                      const SizedBox(height: 6),
                      Text(
                        _timeFmt.format(m.createdAt.toLocal()),
                        style: TextStyle(color: t.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
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
                style: TextStyle(color: t.textMuted, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
