import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BrandedSplashScreen extends StatefulWidget {
  const BrandedSplashScreen({super.key});

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(156, 156),
                painter: _BrandSplashPainter(progress: _controller.value),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandSplashPainter extends CustomPainter {
  const _BrandSplashPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.42;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.gold, AppColors.purple, AppColors.gold],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + progress * math.pi * 2,
      math.pi * 1.42,
      false,
      ringPaint,
    );

    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()..color = const Color(0xFF17131F),
    );

    final road = Path()
      ..moveTo(center.dx - 28, center.dy + 32)
      ..quadraticBezierTo(center.dx - 10, center.dy + 8, center.dx, center.dy)
      ..quadraticBezierTo(
          center.dx + 13, center.dy + 12, center.dx + 30, center.dy + 31);
    canvas.drawPath(
      road,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final bodyPaint = Paint()
      ..color = AppColors.purple
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 8), width: 62, height: 25),
        const Radius.circular(7),
      ),
      bodyPaint,
    );
    final cabin = Path()
      ..moveTo(center.dx - 18, center.dy + 4)
      ..lineTo(center.dx - 8, center.dy - 10)
      ..lineTo(center.dx + 14, center.dy - 10)
      ..lineTo(center.dx + 24, center.dy + 4)
      ..close();
    canvas.drawPath(cabin, bodyPaint);

    final cutPaint = Paint()..color = AppColors.backgroundPrimary;
    canvas.drawCircle(center.translate(-20, 21), 6.2, cutPaint);
    canvas.drawCircle(center.translate(20, 21), 6.2, cutPaint);

    final crownTop = center.dy - 32 + math.sin(progress * math.pi * 2) * 2;
    final crown = Path()
      ..moveTo(center.dx - 24, crownTop + 18)
      ..lineTo(center.dx - 20, crownTop)
      ..lineTo(center.dx - 7, crownTop + 12)
      ..lineTo(center.dx, crownTop - 4)
      ..lineTo(center.dx + 7, crownTop + 12)
      ..lineTo(center.dx + 20, crownTop)
      ..lineTo(center.dx + 24, crownTop + 18)
      ..close();
    canvas.drawPath(crown, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant _BrandSplashPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
