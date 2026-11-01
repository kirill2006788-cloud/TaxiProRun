import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';

/// Русские тексты и сценарий разрешения геолокации.
abstract final class LocationPermissionCopy {
  static const title = 'Доступ к геолокации';

  static const body =
      'КОРОЛИ ДОРОГ использует геолокацию, чтобы показать ваше '
      'местоположение на карте, подобрать ближайших водителей и '
      'построить маршрут поездки.';

  static const whileInUse =
      'Разрешите доступ «При использовании приложения» — этого '
      'достаточно для заказа такси.';

  static const deniedHint =
      'Без геолокации можно указать адреса вручную, но карта и '
      'поиск рядом будут ограничены.';

  static const permanentlyDenied =
      'Геолокация отключена для приложения. Включите её в настройках '
      'телефона: Настройки → КОРОЛИ ДОРОГ → Геолокация.';

  static const openSettings = 'Открыть настройки';
  static const allow = 'Разрешить';
  static const later = 'Позже';
  static const continueManual = 'Указать адрес вручную';
}

class LocationPermissionFlow {
  LocationPermissionFlow._();

  /// Запрос разрешения; при необходимости показывает диалог с русским текстом.
  static Future<PermissionStatus> ensure(
    BuildContext context, {
    bool showRationaleIfDenied = true,
  }) async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted || status.isLimited) return status;

    if (!context.mounted) return status;

    final shouldAsk = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _LocationRationaleDialog(),
    );

    if (shouldAsk != true) return status;
    status = await Permission.locationWhenInUse.request();

    if (!context.mounted) return status;

    if (status.isPermanentlyDenied && showRationaleIfDenied) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(LocationPermissionCopy.title),
          content: const Text(LocationPermissionCopy.permanentlyDenied),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(LocationPermissionCopy.later),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text(LocationPermissionCopy.openSettings),
            ),
          ],
        ),
      );
    } else if (status.isDenied && showRationaleIfDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(LocationPermissionCopy.deniedHint)),
      );
    }

    return status;
  }
}

class _LocationRationaleDialog extends StatelessWidget {
  const _LocationRationaleDialog();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.my_location_rounded, color: AppColors.purple),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text(LocationPermissionCopy.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocationPermissionCopy.body,
            style: TextStyle(color: p.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            LocationPermissionCopy.whileInUse,
            style: TextStyle(
              color: p.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(LocationPermissionCopy.continueManual),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(LocationPermissionCopy.allow),
        ),
      ],
    );
  }
}
