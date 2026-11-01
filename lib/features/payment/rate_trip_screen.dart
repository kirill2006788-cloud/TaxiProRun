import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/services/api_services.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/app_snackbar.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/action_buttons.dart';
import '../booking/providers/booking_provider.dart';
import '../profile/providers/profile_provider.dart';

class RateTripArgs {
  const RateTripArgs({
    required this.orderId,
    this.fromAddress,
    this.toAddress,
    this.price,
    this.driverName,
    this.driverRating,
    this.driverPlate,
    this.carModel,
  });

  final String orderId;
  final String? fromAddress;
  final String? toAddress;
  final double? price;
  final String? driverName;
  final double? driverRating;
  final String? driverPlate;
  final String? carModel;
}

const _ratingTags = <({String label, IconData icon})>[
  (label: 'Забота', icon: Icons.favorite_rounded),
  (label: 'Чистый салон', icon: Icons.cleaning_services_rounded),
  (label: 'Комфортно', icon: Icons.tire_repair_rounded),
  (label: 'Вежливость', icon: Icons.sentiment_satisfied_alt_rounded),
];

/// Оценка поездки → POST /api/orders/:id/rate
class RateTripScreen extends StatefulWidget {
  const RateTripScreen({super.key, required this.args});

  final RateTripArgs args;

  @override
  State<RateTripScreen> createState() => _RateTripScreenState();
}

class _RateTripScreenState extends State<RateTripScreen> {
  int _rating = 5;
  int _tipRub = 0;
  final _commentCtrl = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String? _composedComment() {
    final parts = <String>[
      ..._selectedTags,
      if (_tipRub > 0) 'Чаевые: $_tipRub ₽',
      if (_commentCtrl.text.trim().isNotEmpty) _commentCtrl.text.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join('. ');
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final isDemo = widget.args.orderId.startsWith('demo-');
    final api = isDemo ? null : ApiServices();
    try {
      if (!isDemo) {
        await api!.order.rateOrder(
          widget.args.orderId,
          rating: _rating,
          comment: _composedComment(),
        );
      }

      if (!mounted) return;

      final booking = context.read<BookingProvider>().booking;
      await context.read<ProfileProvider>().appendOrderHistory({
        'id': widget.args.orderId,
        'from': widget.args.fromAddress ?? booking.fromAddress,
        'to': widget.args.toAddress ?? booking.toAddress,
        'price': booking.estimatedPrice,
        'rating': _rating,
        'tip': _tipRub,
        'at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      context.read<BookingProvider>().reset();
      context.go(AppRoutes.home);
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Не удалось отправить оценку', isError: true);
      }
    } finally {
      api?.dispose();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final gap = compact ? 8.0 : 12.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, gap, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.args.price == null
                              ? 'Поездка завершена'
                              : 'Вы приехали: ${formatPriceExact(widget.args.price!)}',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: compact ? 19 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () {
                          context.read<BookingProvider>().reset();
                          context.go(AppRoutes.home);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Divider(height: gap + 2, color: p.divider),
                  Row(
                    children: [
                      Container(
                        width: compact ? 44 : 50,
                        height: compact ? 44 : 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.args.driverName ?? 'Водитель',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              [
                                if (widget.args.driverRating != null)
                                  '★ ${widget.args.driverRating!.toStringAsFixed(2)}',
                                if ((widget.args.carModel ?? '').isNotEmpty)
                                  widget.args.carModel!,
                                if ((widget.args.driverPlate ?? '').isNotEmpty)
                                  widget.args.driverPlate!,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: compact ? 68 : 82,
                        height: compact ? 42 : 50,
                        child: Image.asset(
                          'assets/images/tariffs/comfort_plus.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.directions_car_filled_rounded,
                            color: AppColors.gold,
                            size: 38,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gap),
                  Text(
                    'Что вам особенно понравилось?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: compact ? 18 : 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ваш отзыв останется анонимным',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.textMuted, fontSize: 12),
                  ),
                  SizedBox(height: gap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      final selected = star <= _rating;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(3),
                        constraints: BoxConstraints.tightFor(
                          width: compact ? 44 : 50,
                          height: compact ? 44 : 50,
                        ),
                        onPressed: () => setState(() => _rating = star),
                        icon: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color:
                              selected ? AppColors.gold : AppColors.textMuted,
                          size: compact ? 36 : 42,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: gap),
                  Row(
                    children: _ratingTags.map((tag) {
                      final selected = _selectedTags.contains(tag.label);
                      return Expanded(
                        child: _FeedbackTag(
                          label: tag.label,
                          icon: tag.icon,
                          selected: selected,
                          compact: compact,
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedTags.remove(tag.label);
                              } else {
                                _selectedTags.add(tag.label);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: gap),
                  Container(
                    padding: EdgeInsets.all(compact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: p.bgElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Чаевые водителю',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [0, 50, 100, 200].map((tip) {
                            final selected = _tipRub == tip;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      tip == 0 ? 'Без' : '$tip ₽',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  selected: selected,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _tipRub = tip),
                                  selectedColor:
                                      AppColors.gold.withValues(alpha: 0.22),
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    height: compact ? 46 : 50,
                    child: TextField(
                      controller: _commentCtrl,
                      maxLines: 1,
                      maxLength: 300,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) =>
                          null,
                      decoration: const InputDecoration(
                        hintText: 'Комментарий водителю',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_submitting)
                    const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    GoldActionButton(
                      label: 'Готово',
                      onPressed: _submit,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackTag extends StatelessWidget {
  const _FeedbackTag({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: compact ? 42 : 48,
              height: compact ? 42 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.gold
                    : AppColors.gold.withValues(alpha: 0.12),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.black : AppColors.gold,
                size: compact ? 21 : 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: compact ? 9 : 10,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
