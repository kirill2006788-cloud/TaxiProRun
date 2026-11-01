import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/config/map_config.dart';
import '../../core/theme/app_theme.dart';
import 'map_geo.dart';

/// Премиум-заглушка навигации водителя (dark/light).
class PremiumNavMapCanvas extends StatefulWidget {
  const PremiumNavMapCanvas({
    super.key,
    this.routePoints = const [],
    this.progress,
    this.demoCruise = false,
    this.showSetupHint = true,
  });

  final List<MapPoint> routePoints;
  final double? progress;
  final bool demoCruise;
  final bool showSetupHint;

  @override
  State<PremiumNavMapCanvas> createState() => _PremiumNavMapCanvasState();
}

class _PremiumNavMapCanvasState extends State<PremiumNavMapCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _cruise;
  late final AnimationController _pulse;
  double _progress = 0.2;

  List<MapPoint> get _route => widget.routePoints.length >= 2
      ? widget.routePoints
      : widget.demoCruise
          ? kDefaultNavRoute
          : const [];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _cruise = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..addListener(() {
        if (widget.progress == null) {
          setState(() => _progress = 0.08 + _cruise.value * 0.8);
        }
      });
    if (widget.demoCruise && widget.progress == null) {
      _cruise.repeat();
    }
    if (widget.progress != null) _progress = widget.progress!;
  }

  @override
  void didUpdateWidget(covariant PremiumNavMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != null) {
      _cruise.stop();
      _progress = widget.progress!;
    } else if (widget.demoCruise && !_cruise.isAnimating) {
      _cruise.repeat();
    } else if (!widget.demoCruise && _cruise.isAnimating) {
      _cruise.stop();
    }
  }

  @override
  void dispose() {
    _cruise.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: Listenable.merge([_cruise, _pulse]),
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _NavPainter(
                route: _route,
                progress: _progress,
                pulse: _pulse.value,
                dark: dark,
              ),
            ),
            if (widget.showSetupHint)
              Positioned(
                top: 12,
                left: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: (dark ? const Color(0xFF1A1A1E) : Colors.white)
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MapConfig.isMapKitEnabled
                          ? AppColors.success.withValues(alpha: 0.5)
                          : AppColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      MapConfig.isMapKitEnabled
                          ? 'MapKit · ключ готов'
                          : 'ETA / дистанция · внешняя навигация',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MapConfig.isMapKitEnabled
                            ? AppColors.success
                            : (dark ? AppColors.gold : AppColors.goldDark),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NavPainter extends CustomPainter {
  _NavPainter({
    required this.route,
    required this.progress,
    required this.pulse,
    required this.dark,
  });

  final List<MapPoint> route;
  final double progress;
  final double pulse;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF10131A), Color(0xFF0C0E14), Color(0xFF14101C)]
          : const [Color(0xFFE7ECF5), Color(0xFFDCE3EE), Color(0xFFE4DEEF)],
    );
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = base.createShader(Offset.zero & size));

    final street = Paint()
      ..color = dark ? const Color(0xFF2A303C) : const Color(0xFFC2C9D6)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.15 + i * 0.16);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 12), street);
      final x = size.width * (0.18 + i * 0.16);
      canvas.drawLine(Offset(x, 0), Offset(x - 20, size.height), street);
    }

    final proj = MapProjection.of(route, size);
    final offsets = proj.toOffsets();
    if (offsets.length < 2) return;

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.3)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          offsets.first,
          offsets.last,
          [AppColors.purple, AppColors.gold],
        )
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    _pin(canvas, offsets.first, AppColors.success, 'A');
    _pin(canvas, offsets.last, AppColors.gold, 'B');

    final at = proj.atProgress(progress);
    canvas.save();
    canvas.translate(at.offset.dx, at.offset.dy);
    canvas.rotate(at.bearing + math.pi / 2);
    canvas.drawCircle(
      Offset.zero,
      20 + pulse * 4,
      Paint()..color = AppColors.gold.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -16, 20, 32),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF1A1A22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, 2, 16, 10),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.gold,
    );
    canvas.restore();
  }

  void _pin(Canvas canvas, Offset c, Color color, String label) {
    canvas.drawCircle(c, 10, Paint()..color = color);
    canvas.drawCircle(c, 5, Paint()..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - 22));
  }

  @override
  bool shouldRepaint(covariant _NavPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.dark != dark;
}
