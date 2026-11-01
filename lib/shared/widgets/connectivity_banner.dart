import 'package:flutter/material.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../core/theme/app_theme.dart';

/// Компактный баннер «Нет сети» над контентом shell.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final _monitor = ConnectivityMonitor.instance;

  @override
  void initState() {
    super.initState();
    _monitor.start();
    _monitor.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _monitor.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _monitor.state;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: state == AppConnectivityState.online
          ? const SizedBox.shrink(key: ValueKey('network-online'))
          : _NetworkStatusBar(
              key: ValueKey(state),
              state: state,
            ),
    );
  }
}

class _NetworkStatusBar extends StatelessWidget {
  const _NetworkStatusBar({super.key, required this.state});

  final AppConnectivityState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final restoring = state == AppConnectivityState.restoring;
    final serverUnavailable = state == AppConnectivityState.serverUnavailable;
    final accent = restoring ? AppColors.goldDark : AppColors.error;
    return Material(
      color: palette.bgSecondary.withValues(alpha: 0.96),
      child: Container(
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: accent.withValues(alpha: 0.45))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            if (restoring)
              SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            else
              Icon(
                serverUnavailable
                    ? Icons.cloud_off_rounded
                    : Icons.wifi_off_rounded,
                color: accent,
                size: 18,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                restoring
                    ? 'Восстанавливаем соединение…'
                    : serverUnavailable
                        ? 'Сервер временно недоступен'
                        : 'Нет подключения к интернету',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
