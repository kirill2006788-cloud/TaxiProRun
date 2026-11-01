import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'map_geo.dart';
import 'map_vehicle_marker.dart';

/// Премиум dark/light canvas «как Go»: улицы, маршрут, A/B, машинка.
class PremiumMapCanvas extends StatefulWidget {
  const PremiumMapCanvas({
    super.key,
    this.routePoints = const [],
    this.driverLat,
    this.driverLng,
    this.showDriverMarker = false,
    this.showUserPin = false,
    this.nearbyVehicles = const [],
    this.demoCruise = false,
    this.showSetupHint = true,
    this.mapKitKeyPresent = false,
  });

  final List<MapPoint> routePoints;
  final double? driverLat;
  final double? driverLng;
  final bool showDriverMarker;
  final bool showUserPin;
  final List<MapPoint> nearbyVehicles;

  /// Медленный автопрогон машинки по маршруту, пока нет сокет-локации.
  final bool demoCruise;
  final bool showSetupHint;
  final bool mapKitKeyPresent;

  @override
  State<PremiumMapCanvas> createState() => _PremiumMapCanvasState();
}

class _PremiumMapCanvasState extends State<PremiumMapCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _cruise;
  late final AnimationController _pulse;
  late final AnimationController _move;

  double _progress = 0.08;
  double _fromProgress = 0.08;
  double _toProgress = 0.08;

  List<MapPoint> get _route => widget.routePoints.length >= 2
      ? widget.routePoints
      : widget.demoCruise
          ? kDefaultMockRoute
          : const [];

  @override
  void initState() {
    super.initState();
    _cruise = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..addListener(_onCruise);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _move = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        setState(() {
          _progress = ui.lerpDouble(
                _fromProgress,
                _toProgress,
                Curves.easeOutCubic.transform(_move.value),
              ) ??
              _toProgress;
        });
      });

    _syncCruise();
    _applyDriverLocation(animate: false);
  }

  @override
  void didUpdateWidget(covariant PremiumMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demoCruise != widget.demoCruise ||
        oldWidget.showDriverMarker != widget.showDriverMarker ||
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng) {
      _syncCruise();
      _applyDriverLocation(animate: true);
    }
  }

  void _syncCruise() {
    final hasLive = widget.driverLat != null && widget.driverLng != null;
    if (widget.demoCruise && widget.showDriverMarker && !hasLive) {
      if (!_cruise.isAnimating) _cruise.repeat();
    } else {
      _cruise.stop();
    }
  }

  void _onCruise() {
    if (!mounted) return;
    setState(() {
      _progress = 0.05 + _cruise.value * 0.85;
    });
  }

  void _applyDriverLocation({required bool animate}) {
    final lat = widget.driverLat;
    final lng = widget.driverLng;
    if (lat == null || lng == null || !widget.showDriverMarker) return;

    // Проекция на маршрут по гео — приближённо через временный Size.
    // Реальный прогресс уточняется в painter; здесь — по относительной широте.
    final route = _route;
    if (route.length < 2) return;
    final first = route.first;
    final last = route.last;
    final dLat = last.lat - first.lat;
    final dLng = last.lng - first.lng;
    final denom = dLat * dLat + dLng * dLng;
    final t = denom < 1e-12
        ? 0.0
        : (((lat - first.lat) * dLat + (lng - first.lng) * dLng) / denom)
            .clamp(0.0, 1.0);

    _fromProgress = _progress;
    _toProgress = t;
    if (animate) {
      _move
        ..reset()
        ..forward();
    } else {
      _progress = t;
    }
  }

  @override
  void dispose() {
    _cruise.dispose();
    _pulse.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkTheme;
    final pulse = _pulse.value;

    return AnimatedBuilder(
      animation: Listenable.merge([_cruise, _pulse, _move]),
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _PremiumMapPainter(
                route: _route,
                progress: widget.showDriverMarker ? _progress : null,
                dark: dark,
                pulse: pulse,
                showUserPin: widget.showUserPin,
                showDriver: widget.showDriverMarker,
                nearbyVehicles: widget.nearbyVehicles,
              ),
            ),
            // Soft vignette
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.15,
                  colors: [
                    Colors.transparent,
                    (dark ? Colors.black : const Color(0xFF1A1028))
                        .withValues(alpha: dark ? 0.35 : 0.08),
                  ],
                ),
              ),
            ),
            if (widget.showSetupHint)
              Positioned(
                top: 12,
                left: 12,
                child: _MapModeChip(
                  keyPresent: widget.mapKitKeyPresent,
                  dark: dark,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapModeChip extends StatelessWidget {
  const _MapModeChip({required this.keyPresent, required this.dark});

  final bool keyPresent;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ok = keyPresent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF16161A) : Colors.white)
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ok
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.gold.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.map_rounded : Icons.map_outlined,
              size: 14,
              color: ok ? AppColors.success : AppColors.gold,
            ),
            const SizedBox(width: 6),
            Text(
              ok ? 'MapKit · ключ готов' : 'Preview · без ключа',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ok
                    ? AppColors.success
                    : (dark ? AppColors.gold : AppColors.goldDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumMapPainter extends CustomPainter {
  _PremiumMapPainter({
    required this.route,
    required this.dark,
    required this.pulse,
    required this.showUserPin,
    required this.showDriver,
    required this.nearbyVehicles,
    this.progress,
  });

  final List<MapPoint> route;
  final bool dark;
  final double pulse;
  final bool showUserPin;
  final bool showDriver;
  final List<MapPoint> nearbyVehicles;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size);
    _paintStreets(canvas, size);

    final projectionPoints = <MapPoint>[...route, ...nearbyVehicles];
    final proj = MapProjection.of(projectionPoints, size, padding: 0.14);
    final offsets = route.map(proj.toOffset).toList(growable: false);
    if (offsets.length >= 2) {
      _paintRouteGlow(canvas, offsets);
      _paintRoute(canvas, offsets);
      _paintPin(canvas, offsets.first, label: 'A', color: AppColors.success);
      _paintPin(canvas, offsets.last, label: 'B', color: AppColors.gold);
    }

    if (showUserPin && offsets.isNotEmpty) {
      final p = offsets.first;
      canvas.drawCircle(
        p,
        18 + pulse * 6,
        Paint()..color = AppColors.purple.withValues(alpha: 0.18 + pulse * 0.1),
      );
      canvas.drawCircle(p, 7, Paint()..color = AppColors.purple);
      canvas.drawCircle(p, 3.2, Paint()..color = Colors.white);
    }

    for (var i = 0; i < nearbyVehicles.length; i++) {
      final point = nearbyVehicles[i];
      final offset = proj.toOffset(point);
      if (offset.dx < -24 ||
          offset.dy < -24 ||
          offset.dx > size.width + 24 ||
          offset.dy > size.height + 24) {
        continue;
      }
      _paintFlatVehicle(canvas, offset, mapVehicleAngleForIndex(i), i);
    }

    if (showDriver && progress != null && offsets.length >= 2) {
      final at = proj.atProgress(progress!);
      _paintCar(canvas, at.offset, at.bearing, pulse);
    }
  }

  void _paintBase(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [
              Color(0xFF12141C),
              Color(0xFF0E1016),
              Color(0xFF15101F),
            ]
          : const [
              Color(0xFFE8ECF4),
              Color(0xFFDDE3EE),
              Color(0xFFE6E0F0),
            ],
    );
    canvas.drawRect(rect, Paint()..shader = grad.createShader(rect));

    // Water-ish blobs
    final water = Paint()
      ..color = (dark ? const Color(0xFF1A2740) : const Color(0xFFB8CDE8))
          .withValues(alpha: dark ? 0.45 : 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.62),
        width: size.width * 0.42,
        height: size.height * 0.28,
      ),
      water,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.18, size.height * 0.22),
        width: size.width * 0.28,
        height: size.height * 0.16,
      ),
      water,
    );

    // Park patch
    final park = Paint()
      ..color = (dark ? const Color(0xFF1A2A22) : const Color(0xFFC5D9C4))
          .withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.55,
          size.width * 0.32,
          size.height * 0.22,
        ),
        const Radius.circular(28),
      ),
      park,
    );
  }

  void _paintStreets(Canvas canvas, Size size) {
    final major = Paint()
      ..color = (dark ? const Color(0xFF2A2E3A) : const Color(0xFFC5CBD6))
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = (dark ? const Color(0xFF22262F) : const Color(0xFFD2D7E0))
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void bezier(
      Paint paint,
      double x0,
      double y0,
      double x1,
      double y1,
      double x2,
      double y2,
    ) {
      final path = Path()
        ..moveTo(size.width * x0, size.height * y0)
        ..quadraticBezierTo(
          size.width * x1,
          size.height * y1,
          size.width * x2,
          size.height * y2,
        );
      canvas.drawPath(path, paint);
    }

    bezier(major, 0.0, 0.35, 0.35, 0.38, 1.0, 0.28);
    bezier(major, 0.0, 0.72, 0.4, 0.68, 1.0, 0.78);
    bezier(major, 0.32, 0.0, 0.38, 0.45, 0.28, 1.0);
    bezier(major, 0.68, 0.0, 0.62, 0.5, 0.78, 1.0);

    for (var i = 0; i < 6; i++) {
      final t = 0.12 + i * 0.14;
      bezier(minor, 0.0, t, 0.5, t + 0.04, 1.0, t - 0.02);
      bezier(minor, t, 0.0, t + 0.05, 0.5, t - 0.03, 1.0);
    }

    // Block footprints
    final block = Paint()
      ..color = (dark ? const Color(0xFF1C1F28) : const Color(0xFFD8DCE6))
          .withValues(alpha: 0.85);
    final rng = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 18 + rng.nextDouble() * 36;
      final h = 14 + rng.nextDouble() * 28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(4),
        ),
        block,
      );
    }
  }

  void _paintRouteGlow(Canvas canvas, List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF16D469).withValues(alpha: dark ? 0.32 : 0.22)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _paintRoute(Canvas canvas, List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF111315).withValues(alpha: dark ? 0.78 : 0.35)
        ..strokeWidth = 7.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF16D469)
        ..strokeWidth = 4.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintPin(Canvas canvas, Offset c,
      {required String label, required Color color}) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(c.translate(0, 2), 11, shadow);

    final path = Path()
      ..moveTo(c.dx, c.dy + 14)
      ..quadraticBezierTo(c.dx - 14, c.dy - 2, c.dx - 10, c.dy - 12)
      ..arcToPoint(
        Offset(c.dx + 10, c.dy - 12),
        radius: const Radius.circular(12),
        clockwise: true,
      )
      ..quadraticBezierTo(c.dx + 14, c.dy - 2, c.dx, c.dy + 14)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      Offset(c.dx, c.dy - 8),
      7.5,
      Paint()..color = Colors.white,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - 8 - tp.height / 2));
  }

  void _paintCar(Canvas canvas, Offset c, double bearing, double pulse) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(bearing + math.pi / 2);

    canvas.drawCircle(
      Offset.zero,
      22 + pulse * 4,
      Paint()..color = AppColors.gold.withValues(alpha: 0.16 + pulse * 0.08),
    );

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -18, 22, 36),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF1A1A22));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -12, 16, 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF3A3A48),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, 4, 18, 10),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.gold,
    );
    // headlights
    canvas.drawCircle(
      const Offset(-6, -16),
      2.2,
      Paint()..color = const Color(0xFFFFF3C4),
    );
    canvas.drawCircle(
      const Offset(6, -16),
      2.2,
      Paint()..color = const Color(0xFFFFF3C4),
    );
    canvas.restore();
  }

  void _paintFlatVehicle(Canvas canvas, Offset c, double angle, int index) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);

    final scale = 0.92 + (index % 3) * 0.04;
    canvas.scale(scale);

    canvas.drawOval(
      const Rect.fromLTWH(-16, 7, 32, 12),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final body = Path()
      ..moveTo(0, -18)
      ..cubicTo(10, -16, 15, -7, 14, 5)
      ..cubicTo(12, 17, 4, 20, 0, 20)
      ..cubicTo(-4, 20, -12, 17, -14, 5)
      ..cubicTo(-15, -7, -10, -16, 0, -18)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF17171B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(body, Paint()..color = const Color(0xFFFFD414));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6, -11, 12, 10),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFFF2A8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, 5, 16, 7),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFE0A500),
    );
    canvas.drawCircle(
        const Offset(-4, -16), 1.8, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(4, -16), 1.8, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PremiumMapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.dark != dark ||
        oldDelegate.showDriver != showDriver ||
        oldDelegate.nearbyVehicles != nearbyVehicles ||
        oldDelegate.route != route;
  }
}
