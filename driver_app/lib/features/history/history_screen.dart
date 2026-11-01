import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';



import '../../core/theme/app_theme.dart';

import '../../models/models.dart';

import '../../providers/app_providers.dart';

import '../../shared/widgets.dart';

import '../../shared/widgets/service_badge.dart';



enum _HistoryPeriod { day, week, month }



class HistoryScreen extends StatefulWidget {

  const HistoryScreen({super.key});



  @override

  State<HistoryScreen> createState() => _HistoryScreenState();

}



class _HistoryScreenState extends State<HistoryScreen> {

  _HistoryPeriod _period = _HistoryPeriod.day;



  List<TripHistoryItem> _filter(List<TripHistoryItem> history) {

    final now = DateTime.now();

    final start = switch (_period) {

      _HistoryPeriod.day => DateTime(now.year, now.month, now.day),

      _HistoryPeriod.week => now.subtract(const Duration(days: 7)),

      _HistoryPeriod.month => DateTime(now.year, now.month, 1),

    };

    return history.where((t) => !t.completedAt.isBefore(start)).toList();

  }



  @override

  Widget build(BuildContext context) {

    final historyAll = context.watch<OrdersProvider>().history;

    final history = _filter(historyAll);

    final total = history.fold<int>(0, (sum, t) => sum + t.earningsRub);

    final commissionTotal = history.fold<int>(

      0,

      (sum, t) => sum + (t.commissionRub ?? 0),

    );

    final tipsTotal = history.fold<int>(

      0,

      (sum, t) => sum + (t.tipsRub ?? 0),

    );

    final dateFmt = DateFormat('d MMMM, HH:mm', 'ru_RU');

    final t = context.tokens;

    final gold = t.isDark ? AppColors.gold : AppColors.goldDark;



    return Scaffold(

      appBar: AppBar(title: const Text('Поездки')),

      body: Column(

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),

            child: SegmentedButton<_HistoryPeriod>(

              segments: const [

                ButtonSegment(

                  value: _HistoryPeriod.day,

                  label: Text('День'),

                ),

                ButtonSegment(

                  value: _HistoryPeriod.week,

                  label: Text('Неделя'),

                ),

                ButtonSegment(

                  value: _HistoryPeriod.month,

                  label: Text('Месяц'),

                ),

              ],

              selected: {_period},

              onSelectionChanged: (value) {

                setState(() => _period = value.first);

              },

            ),

          ),

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

            child: Container(

              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                gradient: LinearGradient(

                  begin: Alignment.topLeft,

                  end: Alignment.bottomRight,

                  colors: [

                    AppColors.purple.withValues(alpha: t.isDark ? 0.22 : 0.12),

                    AppColors.gold.withValues(alpha: t.isDark ? 0.1 : 0.08),

                  ],

                ),

                borderRadius: BorderRadius.circular(18),

                border: Border.all(

                  color: t.border.withValues(alpha: t.isDark ? 0.5 : 0.8),

                ),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.05),

                    blurRadius: 16,

                    offset: const Offset(0, 6),

                  ),

                ],

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      Icon(Icons.account_balance_wallet_outlined, color: gold),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              'Заработок',

                              style: TextStyle(

                                color: t.textSecondary,

                                fontSize: 13,

                              ),

                            ),

                            Text(

                              '$total ₽',

                              style: TextStyle(

                                color: gold,

                                fontSize: 22,

                                fontWeight: FontWeight.w700,

                              ),

                            ),

                          ],

                        ),

                      ),

                      Text(

                        '${history.length} поездок',

                        style: TextStyle(color: t.textMuted),

                      ),

                    ],

                  ),

                  const SizedBox(height: 12),

                  Row(

                    children: [

                      Expanded(

                        child: _SummaryChip(

                          label: 'Комиссия',

                          value: commissionTotal > 0 ? '−$commissionTotal ₽' : '—',

                        ),

                      ),

                      const SizedBox(width: 8),

                      Expanded(

                        child: _SummaryChip(

                          label: 'Чаевые',

                          value: tipsTotal > 0 ? '+$tipsTotal ₽' : '—',

                        ),

                      ),

                    ],

                  ),

                ],

              ),

            ),

          ),

          Expanded(

            child: history.isEmpty

                ? EmptyState(

                    icon: Icons.route_outlined,

                    title: 'Пока нет поездок',

                    subtitle: 'Завершённые заказы и заработок появятся здесь',

                  )

                : ListView.separated(

                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),

                    itemCount: history.length,

                    separatorBuilder: (_, __) => const SizedBox(height: 10),

                    itemBuilder: (context, index) {

                      final trip = history[index];

                      return _TripCard(trip: trip, dateFmt: dateFmt);

                    },

                  ),

          ),

        ],

      ),

    );

  }

}



class _SummaryChip extends StatelessWidget {

  const _SummaryChip({required this.label, required this.value});



  final String label;

  final String value;



  @override

  Widget build(BuildContext context) {

    final t = context.tokens;

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      decoration: BoxDecoration(

        color: t.elevated,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: t.border),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(label, style: TextStyle(color: t.textMuted, fontSize: 11)),

          Text(

            value,

            style: TextStyle(

              color: t.textPrimary,

              fontWeight: FontWeight.w700,

              fontSize: 13,

            ),

          ),

        ],

      ),

    );

  }

}



class _TripCard extends StatelessWidget {

  const _TripCard({required this.trip, required this.dateFmt});



  final TripHistoryItem trip;

  final DateFormat dateFmt;



  @override

  Widget build(BuildContext context) {

    final t = context.tokens;

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: softSurface(context),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Text(

                dateFmt.format(trip.completedAt),

                style: TextStyle(

                  color: t.textMuted,

                  fontSize: 12,

                ),

              ),

              const Spacer(),

              ServiceTypeBadge(serviceType: trip.serviceType, compact: true),

            ],

          ),

          const SizedBox(height: 10),

          Text(

            trip.pickup,

            style: TextStyle(

              color: t.textPrimary,

              fontWeight: FontWeight.w500,

            ),

          ),

          const SizedBox(height: 4),

          Text(

            '→ ${trip.dropoff}',

            style: TextStyle(color: t.textSecondary, fontSize: 13),

          ),

          const SizedBox(height: 12),

          Row(

            children: [

              Text(

                trip.clientName,

                style: TextStyle(color: t.textMuted, fontSize: 13),

              ),

              const SizedBox(width: 12),

              const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),

              const SizedBox(width: 4),

              Text(

                trip.clientRating > 0

                    ? trip.clientRating.toStringAsFixed(1)

                    : '—',

                style: const TextStyle(

                  color: AppColors.gold,

                  fontWeight: FontWeight.w600,

                ),

              ),

              const Spacer(),

              Text(

                '+${trip.earningsRub} ₽',

                style: const TextStyle(

                  color: AppColors.success,

                  fontWeight: FontWeight.w700,

                  fontSize: 16,

                ),

              ),

            ],

          ),

          const SizedBox(height: 8),

          Row(

            children: [

              Text(

                'Комиссия: ${trip.commissionRub != null ? '−${trip.commissionRub} ₽' : '—'}',

                style: TextStyle(color: t.textMuted, fontSize: 12),

              ),

              const SizedBox(width: 12),

              Text(

                'Чаевые: ${trip.tipsRub != null ? '+${trip.tipsRub} ₽' : '—'}',

                style: TextStyle(color: t.textMuted, fontSize: 12),

              ),

            ],

          ),

        ],

      ),

    );

  }

}

