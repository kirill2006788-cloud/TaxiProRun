import 'package:flutter/material.dart';

import '../../core/api/broadcast_service.dart';
import '../../core/theme/app_theme.dart';

/// Server-managed demand announcement. Hidden when the server has no data.
class DemandBanner extends StatefulWidget {
  const DemandBanner({super.key});

  @override
  State<DemandBanner> createState() => _DemandBannerState();
}

class _DemandBannerState extends State<DemandBanner> {
  final _service = BroadcastService();
  AppBroadcast? _demand;
  bool _expanded = false;
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchActive();
      AppBroadcast? hit;
      for (final b in list) {
        if (_dismissed.contains(b.id)) continue;
        if (b.type == 'surge' ||
            b.type == 'busy' ||
            b.type == 'alert' ||
            b.title.toLowerCase().contains('спрос')) {
          hit = b;
          break;
        }
      }
      hit ??= list.isNotEmpty ? list.first : null;
      if (!mounted) return;
      setState(() => _demand = hit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _demand = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _demand;
    if (b == null || _dismissed.contains(b.id)) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    const accent = Color(0xFFE67E22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined,
                      color: accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title.isNotEmpty ? b.title : 'Высокий спрос',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          b.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _dismissed.add(b.id)),
                    icon: const Icon(Icons.close, size: 18),
                    color: t.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.35),
                  AppColors.purple.withValues(alpha: 0.2),
                  t.elevated,
                  accent.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.body,
                      style: TextStyle(
                        color: t.textPrimary.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
