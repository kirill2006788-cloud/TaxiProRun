import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:yandex_maps_mapkit/init.dart' as mapkit_init;

import 'core/api/app_services.dart';
import 'core/auth/auth_store.dart';
import 'core/config/map_config.dart';
import 'core/router/app_router.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'shared/widgets/branded_splash.dart';
import 'shared/widgets/connectivity_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  await PushService.instance.init();

  if (MapConfig.isMapKitReady) {
    await mapkit_init.initMapkit(apiKey: MapConfig.apiKey);
  }

  final authStore = AuthStore();
  final savedToken = await authStore.readToken();
  final services = await AppServices.initialize(authToken: savedToken);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(KoroliDorogDriverApp(services: services, authStore: authStore));
}

class KoroliDorogDriverApp extends StatefulWidget {
  const KoroliDorogDriverApp({
    super.key,
    required this.services,
    required this.authStore,
  });

  final AppServices services;
  final AuthStore authStore;

  @override
  State<KoroliDorogDriverApp> createState() => _KoroliDorogDriverAppState();
}

class _KoroliDorogDriverAppState extends State<KoroliDorogDriverApp> {
  late final SettingsProvider _settings;
  late final AuthProvider _auth;
  late final DriverProvider _driver;
  late final GoRouter _router;
  StreamSubscription<Map<String, dynamic>>? _pushTapSubscription;
  bool _pendingPushOpen = false;

  @override
  void initState() {
    super.initState();
    _settings = SettingsProvider(widget.services.settings)..load();
    _auth = AuthProvider(
      store: widget.authStore,
      settingsService: widget.services.settingsService,
    );
    _driver = DriverProvider(widget.services.profile);
    _router = AppRouter.createRouter(
      settings: _settings,
      auth: _auth,
      driver: _driver,
    );
    _pushTapSubscription =
        PushService.instance.onNotificationTap.listen(_openOrdersFromPush);
    final pendingTap = PushService.instance.takePendingTap();
    if (pendingTap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openOrdersFromPush(pendingTap);
      });
    }
    _bootstrap();
  }

  void _openOrdersFromPush(Map<String, dynamic> _) {
    if (!_auth.initialized || !_auth.isLoggedIn) {
      _pendingPushOpen = true;
      return;
    }
    _router.go(AppRoutes.orders);
  }

  Future<void> _bootstrap() async {
    await _auth.bootstrap();
    if (_auth.isLoggedIn) {
      _settings.markLoggedIn();
      await _driver.loadProfile();
      if (_pendingPushOpen) {
        _pendingPushOpen = false;
        _router.go(AppRoutes.orders);
      }
    }
  }

  @override
  void dispose() {
    _pushTapSubscription?.cancel();
    _router.dispose();
    _settings.dispose();
    _driver.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _driver),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider(
            widget.services.orders,
            socket: widget.services.socket,
          ),
        ),
        ChangeNotifierProvider.value(value: _settings),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final light = settings.isLightTheme;
          if (!settings.initialized || !_auth.initialized) {
            return MaterialApp(
              title: 'КОРОЛИ ДОРОГ - Водитель',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settings.themeMode,
              themeAnimationDuration: Duration.zero,
              themeAnimationCurve: Curves.linear,
              home: const BrandedSplashScreen(),
            );
          }
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  light ? Brightness.dark : Brightness.light,
              statusBarBrightness: light ? Brightness.light : Brightness.dark,
            ),
            child: MaterialApp.router(
              title: 'КОРОЛИ ДОРОГ — Водитель',
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
              builder: (context, child) => Stack(
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
              ),
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
