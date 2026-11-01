import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../widgets.dart';

/// Go-like «заработок сегодня» strip for the Orders home.
class EarningsTodayCard extends StatelessWidget {
  const EarningsTodayCard({
    super.key,
    required this.today,
    required this.week,
    this.tripsToday,
  });

  final double today;
  final double week;
  final int? tripsToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gold = t.isDark ? AppColors.gold : AppColors.goldDark;

    return SectionCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go(AppRoutes.profile),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сегодня',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatMoney(today),
                      style: TextStyle(
                        color: gold,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tripsToday != null
                          ? 'Неделя ${formatMoney(week)} · $tripsToday поезд.'
                          : 'Неделя ${formatMoney(week)}',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12,
                      ),
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
  }
}
