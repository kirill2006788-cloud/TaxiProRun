import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Lightweight brand background for auth and onboarding screens.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.intensity = 1,
    this.showNoise = false,
  });

  final Widget child;
  final double intensity;
  final bool showNoise;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(p.bgPrimary, AppColors.purple, 0.10 * intensity)!,
            p.bgPrimary,
            Color.lerp(p.bgPrimary, AppColors.gold, 0.05 * intensity)!,
          ],
          stops: const [0.0, 0.56, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Soft fade + slight rise for screen content entry.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Premium empty state with brand-tinted icon plate.
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.purple.withValues(alpha: 0.18),
                      AppColors.gold.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(icon, size: 40, color: AppColors.purple),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight shimmer block (no extra package).
class ShimmerBlock extends StatefulWidget {
  const ShimmerBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 12,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDarkTheme;
    final base = dark ? p.bgElevated : p.bgElevated;
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + _controller.value * 2.4, 0),
              end: Alignment(-0.2 + _controller.value * 2.4, 0),
              colors: [base, highlight, base],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton rows for trips / history lists.
class TripListSkeleton extends StatelessWidget {
  const TripListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _TripSkeletonCard(),
    );
  }
}

class _TripSkeletonCard extends StatelessWidget {
  const _TripSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.softCard(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBlock(height: 12, width: 96, radius: 6),
              Spacer(),
              ShimmerBlock(height: 22, width: 64, radius: 11),
            ],
          ),
          SizedBox(height: 16),
          ShimmerBlock(height: 14, width: double.infinity, radius: 7),
          SizedBox(height: 10),
          ShimmerBlock(height: 14, width: 220, radius: 7),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerBlock(height: 16, width: 72, radius: 8),
              Spacer(),
              ShimmerBlock(height: 14, width: 80, radius: 7),
            ],
          ),
        ],
      ),
    );
  }
}
