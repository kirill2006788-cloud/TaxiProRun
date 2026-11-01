import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/session/active_order_store.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../shared/widgets/branded_splash.dart';

/// Splash: auth gate + restore active order from prefs on cold start.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_started || !mounted) return;
    _started = true;

    final auth = context.read<AuthProvider>();
    for (var i = 0; i < 80 && !auth.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    if (!mounted) return;

    if (!auth.isAuthenticated) {
      context.go(AppRoutes.auth);
      return;
    }
    if (auth.needsName) {
      context.go(AppRoutes.authName);
      return;
    }
    if (!auth.onboardingCompleted) {
      context.go(AppRoutes.onboarding);
      return;
    }

    final useMock = ApiConfigStore.instance.useMockApi;
    if (!useMock) {
      final restored = await _tryRestoreActiveTrip();
      if (!mounted) return;
      if (restored) return;
    }

    context.go(AppRoutes.home);
  }

  Future<bool> _tryRestoreActiveTrip() async {
    final booking = context.read<BookingProvider>();
    var orderId = await ActiveOrderStore.load();
    final api = booking.apiServices;

    try {
      var order = orderId != null && orderId.isNotEmpty
          ? await api.order.fetchOrder(orderId)
          : null;
      order ??= await api.order.fetchActiveOrder();

      if (order == null || !order.isActive) {
        await ActiveOrderStore.clear();
        return false;
      }

      await ActiveOrderStore.save(order.id);
      booking.restoreFromOrder(order);
      if (!mounted) return true;
      context.go(AppRoutes.activeTrip);
      return true;
    } catch (_) {
      if (orderId != null && orderId.isNotEmpty) {
        await ActiveOrderStore.clear();
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const BrandedSplashScreen();
  }
}
