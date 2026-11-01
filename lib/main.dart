import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:yandex_maps_mapkit/init.dart' as mapkit_init;

import 'core/config/map_config.dart';
import 'core/geo/geo_search_service.dart';
import 'core/router/app_router.dart';
import 'core/services/observability_service.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/booking/providers/booking_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/providers/settings_provider.dart';
import 'features/profile/providers/vehicles_provider.dart';
import 'shared/widgets/connectivity_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  await ObservabilityService.instance.init();
  await PushService.instance.init();

  if (MapConfig.isMapKitReady) {
    await mapkit_init.initMapkit(apiKey: MapConfig.apiKey);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  final authProvider = AuthProvider();
  await authProvider.load();

  runApp(KoroliDorogApp(
    settingsProvider: settingsProvider,
    authProvider: authProvider,
  ));
}

class KoroliDorogApp extends StatefulWidget {
  const KoroliDorogApp({
    super.key,
    required this.settingsProvider,
    required this.authProvider,
  });

  final SettingsProvider settingsProvider;
  final AuthProvider authProvider;

  @override
  State<KoroliDorogApp> createState() => _KoroliDorogAppState();
}

class _KoroliDorogAppState extends State<KoroliDorogApp> {
  late final GoRouter _router;
  late final ProfileProvider _profileProvider;
  late final GeoSearchService _geoSearch;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.authProvider);
    _profileProvider = ProfileProvider();
    _profileProvider.load();
    _geoSearch = GeoSearchService();
  }

  @override
  void dispose() {
    _geoSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GeoSearchService>.value(value: _geoSearch),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider.value(value: _profileProvider),
        ChangeNotifierProvider(
          create: (_) {
            final vehicles = VehiclesProvider();
            vehicles.load();
            return vehicles;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider =
                BookingProvider(settingsProvider: widget.settingsProvider);
            provider.applyDefaultSettings();
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final isLight = settings.themeMode == ThemeMode.light;
          // Update the legacy palette before MaterialApp builds its route tree.
          // This prevents one stale frame of dark colors after a theme toggle.
          AppColors.applyPalette(
            isLight ? AppPalette.light : AppPalette.dark,
          );
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isLight ? Brightness.dark : Brightness.light,
              statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp.router(
            title: 'КОРОЛИ ДОРОГ',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            themeAnimationDuration: Duration.zero,
            themeAnimationCurve: Curves.linear,
            locale: const Locale('ru', 'RU'),
            supportedLocales: const [Locale('ru', 'RU')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final palette = Theme.of(context).extension<AppPalette>();
              if (palette != null) AppColors.applyPalette(palette);
              return Stack(
                children: [
                  Positioned.fill(child: child ?? const SizedBox.shrink()),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: ConnectivityBanner(),
                    ),
                  ),
                ],
              );
            },
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
