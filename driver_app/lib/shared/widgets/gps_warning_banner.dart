import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/api/app_services.dart';
import '../../core/api/driver_location_ticker.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Компактные предупреждения GPS поверх карты (когда водитель на линии).
class GpsWarningBanner extends StatelessWidget {
  const GpsWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<SettingsProvider>().isOnline;
    if (!online) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: AppServices.instance.locationTicker,
      builder: (context, _) {
        final ticker = AppServices.instance.locationTicker;
        final message = _message(ticker);
        if (message == null) return const SizedBox.shrink();
        final t = context.tokens;
        return Material(
          color: AppColors.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => Geolocator.openLocationSettings(),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.gps_off_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String? _message(DriverLocationTicker ticker) {
    if (!ticker.isRunning) {
      return 'GPS недоступен — нажмите, чтобы открыть настройки';
    }
    if (ticker.latestPosition == null) {
      return 'Получаем точную GPS-позицию…';
    }
    if (ticker.isStale) {
      return 'Потерян сигнал GPS — выезжайте на открытое место';
    }
    if (ticker.hasWeakGps) {
      final acc = ticker.accuracyMeters;
      final accLabel = acc == null ? '' : ' · ±${acc.round()} м';
      return 'Слабый GPS$accLabel — точность подачи снижена';
    }
    return null;
  }
}
