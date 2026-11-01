import 'package:flutter/material.dart';
import '../../core/api/broadcast_service.dart';
import '../../core/theme/app_theme.dart';

/// Баннер реальных объявлений, опубликованных диспетчером на сервере.
class BroadcastBanner extends StatefulWidget {
  const BroadcastBanner({
    super.key,
    this.audience = 'clients',
  });

  final String audience;

  @override
  State<BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends State<BroadcastBanner> {
  final _service = BroadcastService();
  List<AppBroadcast> _items = const [];
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<AppBroadcast> list = const [];
    try {
      list = await _service.fetchActive(audience: widget.audience);
    } catch (_) {
      list = const [];
    }
    if (!mounted) return;
    setState(() => _items = list);
  }

  AppBroadcast? _effective() {
    final surge =
        _items.where((b) => !_dismissed.contains(b.id) && b.isSurge).toList();
    if (surge.isNotEmpty) return surge.first;
    final visible = _items.where((b) => !_dismissed.contains(b.id)).toList();
    if (visible.isNotEmpty) return visible.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final b = _effective();
    if (b == null) return const SizedBox.shrink();

    final isSurge = b.isSurge;
    final color = isSurge
        ? const Color(0xFFE67E22)
        : (b.isAlert ? AppColors.error : AppColors.purple);
    final icon = isSurge
        ? Icons.trending_up_rounded
        : (b.isMaintenance
            ? Icons.build_circle_outlined
            : Icons.campaign_outlined);

    final surface =
        context.isDarkTheme ? const Color(0xFF211519) : const Color(0xFFFFF4F4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.backgroundSecondary,
                title: Text(b.title),
                content: Text(b.body),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Понятно'),
                  ),
                ],
              ),
            );
          },
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
                  child: Icon(icon, color: color, size: 19),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _dismissed.add(b.id)),
                  icon: const Icon(Icons.close, size: 18),
                  color: context.palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
