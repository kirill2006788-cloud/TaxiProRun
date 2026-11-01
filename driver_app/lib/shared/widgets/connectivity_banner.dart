import 'package:flutter/material.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../core/theme/app_theme.dart';

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
    if (state == AppConnectivityState.online) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    final restoring = state == AppConnectivityState.restoring;
    final serverUnavailable = state == AppConnectivityState.serverUnavailable;
    final accent = restoring ? AppColors.warning : AppColors.error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Material(
        key: ValueKey(state),
        color: t.surface.withValues(alpha: 0.96),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              if (restoring)
                SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
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
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
