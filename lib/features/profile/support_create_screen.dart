import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/app_error_mapper.dart';
import '../../core/api/services/api_services.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import 'widgets/profile_widgets.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните тему и текст обращения')),
      );
      return;
    }
    setState(() => _sending = true);
    final api = ApiServices();
    try {
      await api.support.createTicket(subject: subject, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Обращение отправлено')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.toRussian(e, fallback: 'Не удалось отправить обращение'),
          ),
        ),
      );
    } finally {
      api.dispose();
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новое обращение'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Опишите ситуацию — служба поддержки ответит в переписке.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          ProfileFormCard(
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
                    hintText: 'Например, проблема с оплатой',
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
                    hintText: 'Подробно опишите, что произошло',
                  ),
                ),
                const SizedBox(height: 16),
                PurpleActionButton(
                  label: _sending ? 'Отправка…' : 'Отправить',
                  loading: _sending,
                  onPressed: _sending ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
