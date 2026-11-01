import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

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

class GoldActionButton extends StatelessWidget {
  const GoldActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading && onPressed != null;
    return ScaleTap(
      enabled: canTap,
      child: ElevatedButton(
        style: AppTheme.goldButton,
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0B0B0E)
                      : AppColors.lightTextPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class PurpleActionButton extends StatelessWidget {
  const PurpleActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading && onPressed != null;
    return ScaleTap(
      enabled: canTap,
      child: FilledButton(
        style: AppTheme.purpleButton,
        onPressed: canTap
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class FeatureChip extends StatelessWidget {
  const FeatureChip({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ScaleTap(
      enabled: onTap != null,
      scale: 0.96,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.purple.withValues(alpha: 0.14)
                  : p.bgSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.purple.withValues(alpha: 0.55)
                    : p.border.withValues(alpha: context.isDarkTheme ? 0.55 : 0.9),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.purple : p.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? p.textPrimary : p.textSecondary,
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
