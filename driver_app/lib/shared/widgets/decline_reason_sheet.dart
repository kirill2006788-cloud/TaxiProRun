import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const kDriverDeclineReasons = <String>[
  'Далеко ехать',
  'Не устраивает цена',
  'Заканчиваю смену',
  'Техническая причина',
  'Другое',
];

/// Optional decline reason. Returns reason label or '' if skipped without reason.
Future<String?> showDeclineReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final t = ctx.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Пропустить заказ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Причина необязательна',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                ),
              ),
              ...kDriverDeclineReasons.map(
                (r) => ListTile(
                  title: Text(r),
                  trailing: Icon(Icons.chevron_right, color: t.textMuted),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Пропустить без причины'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Отмена',
                  style: TextStyle(color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
