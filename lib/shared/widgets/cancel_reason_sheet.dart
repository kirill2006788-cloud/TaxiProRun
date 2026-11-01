import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CancelReason {
  const CancelReason({required this.id, required this.label});

  final String id;
  final String label;
}

const kClientCancelReasons = <CancelReason>[
  CancelReason(id: 'wait_too_long', label: 'Долго ждать'),
  CancelReason(id: 'wrong_address', label: 'Ошибся адресом'),
  CancelReason(id: 'plans_changed', label: 'Изменились планы'),
  CancelReason(id: 'price_high', label: 'Дорого'),
  CancelReason(id: 'found_another', label: 'Нашёл другой вариант'),
  CancelReason(id: 'other', label: 'Другая причина'),
];

/// Bottom sheet with cancel reasons. Returns selected reason id or null.
Future<String?> showCancelReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.paddingOf(ctx).bottom;
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.64;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Почему отменяете?',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Это поможет улучшить сервис',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: kClientCancelReasons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final reason = kClientCancelReasons[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(ctx, reason.id),
                        child: SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reason.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Не отменять'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
