import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/sheet_drag_handle.dart';
import 'map_pin_mode.dart';

/// Go-like нижняя панель: half ↔ expanded по жесту на хэндле.
class MapBottomSheet extends StatefulWidget {
  const MapBottomSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.55,
    this.halfHeightFactor = 0.32,
    this.padding,
    this.collapsed = false,
    this.expandable = true,
    this.fitChild = true,
  });

  final Widget child;
  final double maxHeightFactor;
  final double halfHeightFactor;
  final EdgeInsets? padding;

  /// When true, sheet slides off-screen (map drag).
  final bool collapsed;

  /// Allow half ↔ expanded snap via handle drag.
  final bool expandable;

  /// Keep compact content at its natural size instead of shrinking the whole
  /// sheet when a user has three saved places.
  final bool fitChild;

  @override
  State<MapBottomSheet> createState() => _MapBottomSheetState();
}

class _MapBottomSheetState extends State<MapBottomSheet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final half = screenH * widget.halfHeightFactor.clamp(0.18, 0.7);
    final maxH = screenH * widget.maxHeightFactor.clamp(0.25, 0.92);
    final normalH = widget.expandable && _expanded
        ? maxH
        : half.clamp(0.0, maxH).toDouble();
    final targetH = normalH;

    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        ignoring: widget.collapsed,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: widget.collapsed ? const Offset(0, 1.04) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: widget.collapsed ? 0 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: targetH,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.bgSecondary.withValues(alpha: 0.98),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border(top: BorderSide(color: p.border)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: context.isDarkTheme ? 0.52 : 0.14,
                        ),
                        blurRadius: 32,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: widget.expandable
                            ? (d) {
                                if (d.delta.dy < -4 && !_expanded) {
                                  setState(() => _expanded = true);
                                } else if (d.delta.dy > 4 && _expanded) {
                                  setState(() => _expanded = false);
                                }
                              }
                            : null,
                        onTap: widget.expandable
                            ? () => setState(() => _expanded = !_expanded)
                            : null,
                        child: const SheetDragHandle(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: widget.padding ??
                              EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Align(
                                alignment: Alignment.topCenter,
                                child: widget.fitChild
                                    ? FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.topCenter,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          child: widget.child,
                                        ),
                                      )
                                    : SizedBox(
                                        width: constraints.maxWidth,
                                        height: constraints.maxHeight,
                                        child: widget.child,
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed center pin for pickup / destination selection.
class CenterMapPin extends StatelessWidget {
  const CenterMapPin({
    super.key,
    required this.mode,
    this.etaMinutes,
    this.lifting = false,
  });

  final MapPinMode mode;
  final int? etaMinutes;
  final bool lifting;

  @override
  Widget build(BuildContext context) {
    if (mode == MapPinMode.none) return const SizedBox.shrink();

    final isPickup = mode == MapPinMode.pickup;
    final accent = isPickup ? AppColors.purple : AppColors.gold;
    final letter = isPickup ? 'А' : 'Б';
    final eta = etaMinutes ?? 5;

    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: Offset(0, lifting ? -38 : -26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPickup)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.bgSecondary.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      'Подача ~$eta мин',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              if (isPickup) const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: lifting ? 16 : 10,
                      offset: Offset(0, lifting ? 8 : 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Компактный чип поверх карты: ETA, цена, ожидание.
class MapOverlayChip extends StatelessWidget {
  const MapOverlayChip({
    super.key,
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = accent ?? AppColors.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bgSecondary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkTheme ? 0.36 : 0.1,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Бесплатное ожидание 3 мин с [arrivedAt], затем платное.
class ArrivedWaitChip extends StatefulWidget {
  const ArrivedWaitChip({
    super.key,
    this.arrivedAt,
  });

  static const freeWait = Duration(minutes: 3);

  /// Если null — отсчёт начинается с момента монтирования виджета.
  final DateTime? arrivedAt;

  static String formatMmSs(Duration d) {
    final total = d.inSeconds.clamp(0, 99 * 60 + 59);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  State<ArrivedWaitChip> createState() => _ArrivedWaitChipState();
}

class _ArrivedWaitChipState extends State<ArrivedWaitChip> {
  Timer? _timer;
  late DateTime _started;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _started = widget.arrivedAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(_started);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_started);
      });
    });
  }

  @override
  void didUpdateWidget(covariant ArrivedWaitChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arrivedAt != null && widget.arrivedAt != _started) {
      _started = widget.arrivedAt!;
      _elapsed = DateTime.now().difference(_started);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const free = ArrivedWaitChip.freeWait;
    final isFree = _elapsed < free;
    final shown = isFree ? _elapsed : _elapsed - free;
    final label =
        '${isFree ? 'Бесплатное ожидание' : 'Платное ожидание'} · ${ArrivedWaitChip.formatMmSs(shown)}';
    return MapOverlayChip(
      icon: Icons.hourglass_top_rounded,
      label: label,
      accent: isFree ? AppColors.success : AppColors.gold,
    );
  }
}

/// Карточка водителя: имя, машина, номер, рейтинг, звонок / чат / поделиться.
class TripDriverCard extends StatelessWidget {
  const TripDriverCard({
    super.key,
    required this.name,
    this.plate,
    this.subtitle,
    this.rating,
    this.carAssetPath,
    this.onCall,
    this.onChat,
    this.onShare,
    this.onDetails,
  });

  final String name;
  final String? plate;
  final String? subtitle;
  final double? rating;
  final String? carAssetPath;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final VoidCallback? onShare;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.gold,
                              size: 17,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if ((subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: p.textSecondary),
                        ),
                      ],
                      if ((plate ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.bgSecondary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: p.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            child: Text(
                              plate!,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (carAssetPath != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    height: 48,
                    child: Image.asset(
                      carAssetPath!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_car_filled_rounded,
                        color: AppColors.gold,
                        size: 38,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Divider(height: 1, color: p.divider),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DriverActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Звонок',
                    color: AppColors.success,
                    onTap: onCall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DriverActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Чат',
                    color: AppColors.gold,
                    onTap: onChat,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DriverActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Маршрут',
                    color: AppColors.purple,
                    onTap: onShare,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DriverActionButton(
                    icon: Icons.info_outline_rounded,
                    label: 'Детали',
                    color: AppColors.gold,
                    onTap: onDetails,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverActionButton extends StatelessWidget {
  const _DriverActionButton({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.13),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// UI «Ищем водителя»: компактная панель.
class SearchingDriverPanel extends StatefulWidget {
  const SearchingDriverPanel({
    super.key,
    this.onCancel,
    this.onDetails,
    this.nearbyDriverCount = 0,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onDetails;
  final int nearbyDriverCount;

  @override
  State<SearchingDriverPanel> createState() => _SearchingDriverPanelState();
}

class _SearchingDriverPanelState extends State<SearchingDriverPanel> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.clamp(0, 99).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = widget.nearbyDriverCount > 0 ? widget.nearbyDriverCount : 5;
    final countLabel = '$count ${_carsWord(count)}';
    final waitingForAnswer = widget.nearbyDriverCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.bgElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    waitingForAnswer
                        ? Icons.hourglass_top_rounded
                        : Icons.radar_rounded,
                    color: AppColors.gold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waitingForAnswer ? 'Ждём ответ' : 'Ищем водителя',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        waitingForAnswer
                            ? 'Заказ получили водители · ${_formatElapsed(_elapsed)}'
                            : 'Рядом $countLabel · ${_formatElapsed(_elapsed)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TripSheetAction(
                icon: Icons.close_rounded,
                label: 'Отмена',
                onTap: widget.onCancel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TripSheetAction(
                icon: Icons.info_outline_rounded,
                label: 'Детали',
                onTap: widget.onDetails,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _carsWord(int value) {
    final n = value % 100;
    if (n >= 11 && n <= 14) return 'машин';
    return switch (n % 10) {
      1 => 'машина',
      2 || 3 || 4 => 'машины',
      _ => 'машин',
    };
  }
}

class _TripSheetAction extends StatelessWidget {
  const _TripSheetAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.bgElevated.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: p.textPrimary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
