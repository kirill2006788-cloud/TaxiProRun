import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';

class RegistrationStatusBadge extends StatelessWidget {
  const RegistrationStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _meta(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  /// ТЗ: черновик / на проверке / нужны правки / одобрен / заблокирован.
  static (String, Color, IconData) _meta(String status) {
    final s = normalizeRegistrationStatus(status);
    return switch (s) {
      'completed' => ('Одобрен', AppColors.success, Icons.verified_rounded),
      'pending' => (
          'На проверке',
          AppColors.warning,
          Icons.hourglass_top_rounded
        ),
      'rejected' => ('Нужны правки', AppColors.error, Icons.edit_note_rounded),
      'blocked' => ('Заблокирован', AppColors.error, Icons.block_rounded),
      _ => ('Черновик', AppColors.warning, Icons.drafts_outlined),
    };
  }
}

String registrationStatusTitle(String status) {
  final s = normalizeRegistrationStatus(status);
  return switch (s) {
    'completed' => 'Одобрено',
    'pending' => 'На проверке',
    'rejected' => 'Нужны правки',
    'blocked' => 'Аккаунт заблокирован',
    _ => 'Черновик анкеты',
  };
}

String registrationStatusSubtitle(DriverProfile profile) {
  final s = normalizeRegistrationStatus(profile.registrationStatus);
  if (profile.blocked || s == 'blocked') {
    final reason = profile.blockReason?.trim();
    return (reason != null && reason.isNotEmpty)
        ? reason
        : 'Доступ к линии ограничен. Обратитесь в поддержку.';
  }
  return switch (s) {
    'completed' => 'Вы можете принимать заказы',
    'pending' => 'Администратор проверяет ваши документы',
    'rejected' => profile.rejectionReason?.trim().isNotEmpty == true
        ? profile.rejectionReason!.trim()
        : 'Исправьте данные и отправьте заявку повторно',
    _ => 'Заполните анкету и загрузите документы',
  };
}
