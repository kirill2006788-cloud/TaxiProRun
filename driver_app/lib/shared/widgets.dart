import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// Soft surface card — shadow first, muted border (Yandex Go feel).
BoxDecoration softSurface(
  BuildContext context, {
  bool elevated = false,
  Color? borderColor,
  double radius = 18,
}) {
  final t = context.tokens;
  return BoxDecoration(
    color: elevated ? t.elevated : t.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: (borderColor ?? t.border).withValues(
        alpha: t.isDark ? 0.5 : 0.8,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: t.isDark ? 0.22 : 0.06),
        blurRadius: elevated ? 20 : 14,
        offset: Offset(0, elevated ? 8 : 5),
      ),
    ],
  );
}

/// Visual press scale that does not steal taps from child buttons.
class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

void showDriverSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.error : AppColors.gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: softSurface(context),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.tokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Premium empty / offline placeholder.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(
                      alpha: t.isDark ? 0.16 : 0.1,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 40,
                color: t.isDark ? AppColors.gold : AppColors.goldDark,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class GoldStarRow extends StatelessWidget {
  const GoldStarRow({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = true,
  });

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.25 && (rating - full) < 0.75;
    final almostFull = (rating - full) >= 0.75;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= full || (i == full + 1 && almostFull)
                ? Icons.star_rounded
                : (i == full + 1 && hasHalf)
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: AppColors.gold,
            size: size,
          ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(2),
            style: TextStyle(
              color: AppColors.gold,
              fontSize: size,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.ok,
  });

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final tone = ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            ok ? Icons.check_rounded : Icons.close_rounded,
            size: 16,
            color: tone,
          ),
        ],
      ),
    );
  }
}

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
    final t = context.tokens;
    final base = t.elevated;
    final highlight = t.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.75);

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

class OrderListSkeleton extends StatelessWidget {
  const OrderListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: softSurface(context),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBlock(height: 22, width: 88, radius: 11),
                Spacer(),
                ShimmerBlock(height: 18, width: 72, radius: 8),
              ],
            ),
            SizedBox(height: 16),
            ShimmerBlock(height: 14, width: double.infinity, radius: 7),
            SizedBox(height: 10),
            ShimmerBlock(height: 14, width: 200, radius: 7),
            SizedBox(height: 18),
            ShimmerBlock(height: 48, width: double.infinity, radius: 14),
          ],
        ),
      ),
    );
  }
}

/// Primary gold CTA with light haptic + press scale.
class PrimaryGoldButton extends StatelessWidget {
  const PrimaryGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final canTap = !loading && onPressed != null;
    final t = context.tokens;
    return ScaleTap(
      enabled: canTap,
      child: ElevatedButton(
        onPressed: canTap
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: t.onGold,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = destructive ? AppColors.error : t.textPrimary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        icon,
        color: destructive ? AppColors.error : AppColors.purple,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: t.textMuted, fontSize: 13),
            ),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right, color: t.textMuted)),
    );
  }
}

String formatMoney(double value) {
  final ints = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < ints.length; i++) {
    final fromEnd = ints.length - i;
    buf.write(ints[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buf.write('\u00a0');
    }
  }
  return '${buf.toString()} ₽';
}
