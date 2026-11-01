import 'package:flutter/material.dart';

import '../../core/api/broadcast_service.dart';
import '../../core/theme/app_theme.dart';

class DriverBroadcastBanner extends StatefulWidget {
  const DriverBroadcastBanner({super.key});

  @override
  State<DriverBroadcastBanner> createState() => _DriverBroadcastBannerState();
}

class _DriverBroadcastBannerState extends State<DriverBroadcastBanner> {
  final _service = BroadcastService();
  List<AppBroadcast> _items = const [];
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchActive();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((b) => !_dismissed.contains(b.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final b = visible.first;
    final color = b.isAlert ? AppColors.error : AppColors.purple;
    final t = context.tokens;

    final surface =
        t.isDark ? const Color(0xFF211519) : const Color(0xFFFFF4F4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.campaign_outlined, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      b.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _dismissed.add(b.id)),
                icon: const Icon(Icons.close, size: 18),
                color: t.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
