import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/legal_texts.dart';
import '../../features/active_trip/active_trip_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/name_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/confirmation/confirmation_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/payment/payment_receipt_screen.dart';
import '../../features/payment/payment_screen.dart';
import '../../features/payment/rate_trip_screen.dart';
import '../../features/preferences/preferences_screen.dart';
import '../../features/profile/about_screen.dart';
import '../../features/profile/account_screen.dart';
import '../../features/profile/favorites_screen.dart';
import '../../features/profile/legal_document_screen.dart';
import '../../features/profile/notifications_screen.dart';
import '../../features/profile/payment_methods_screen.dart';
import '../../features/profile/personal_data_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/promo_screen.dart';
import '../../features/profile/referral_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/support_create_screen.dart';
import '../../features/profile/support_tickets_screen.dart';
import '../../features/profile/support_thread_screen.dart';
import '../../features/profile/trip_history_screen.dart';
import '../../features/route/route_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/tariffs/tariffs_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/profile/vehicles_screen.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const auth = '/auth';
  static const authName = '/auth/name';
  static const onboarding = '/';
  static const home = '/home';
  static const trips = '/trips';
  static const profile = '/profile';
  static const personalData = '/profile/personal';
  static const paymentMethods = '/profile/payment-methods';
  static const favorites = '/profile/favorites';
  static const notifications = '/profile/notifications';
  static const settings = '/profile/settings';
  static const account = '/profile/account';
  static const promo = '/profile/promo';
  static const referral = '/profile/referral';
  static const tripHistory = '/profile/trip-history';
  static const privacyPolicy = '/profile/privacy';
  static const terms = '/profile/terms';
  static const about = '/profile/about';
  static const support = '/profile/support';
  static const supportNew = '/profile/support/new';
  static String supportDetail(String id) => '/profile/support/$id';
  static const vehicles = '/profile/vehicles';
  static const route = '/home';
  static const tariffs = '/tariffs';
  static const preferences = '/preferences';
  static const payment = '/payment';
  static const confirmation = '/confirmation';
  static const activeTrip = '/active-trip';
  static const paymentReceipt = '/payment-receipt';
  static const rateTrip = '/rate-trip';

  /// @deprecated Используйте [auth].
  static const login = auth;
}

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthProvider auth) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.splash,
      refreshListenable: auth,
      redirect: (context, state) => _redirect(auth, state),
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.auth,
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: AppRoutes.authName,
          builder: (context, state) => const NameScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const RouteScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  builder: (context, state) => const ProfileScreen(),
                  routes: [
                    GoRoute(
                      path: 'personal',
                      builder: (context, state) => const PersonalDataScreen(),
                    ),
                    GoRoute(
                      path: 'account',
                      builder: (context, state) => const AccountScreen(),
                    ),
                    GoRoute(
                      path: 'promo',
                      builder: (context, state) => const PromoScreen(),
                    ),
                    GoRoute(
                      path: 'referral',
                      builder: (context, state) => const ReferralScreen(),
                    ),
                    GoRoute(
                      path: 'trip-history',
                      builder: (context, state) => const TripHistoryScreen(),
                    ),
                    GoRoute(
                      path: 'payment-methods',
                      builder: (context, state) => const PaymentMethodsScreen(),
                    ),
                    GoRoute(
                      path: 'favorites',
                      builder: (context, state) => const FavoritesScreen(),
                    ),
                    GoRoute(
                      path: 'vehicles',
                      builder: (context, state) => const VehiclesScreen(),
                    ),
                    GoRoute(
                      path: 'notifications',
                      builder: (context, state) => const NotificationsScreen(),
                    ),
                    GoRoute(
                      path: 'settings',
                      builder: (context, state) => const SettingsScreen(),
                    ),
                    GoRoute(
                      path: 'privacy',
                      builder: (context, state) => const LegalDocumentScreen(
                        title: LegalTexts.privacyPolicyTitle,
                        body: LegalTexts.privacyPolicy,
                      ),
                    ),
                    GoRoute(
                      path: 'terms',
                      builder: (context, state) => const LegalDocumentScreen(
                        title: LegalTexts.termsTitle,
                        body: LegalTexts.termsOfUse,
                      ),
                    ),
                    GoRoute(
                      path: 'about',
                      builder: (context, state) => const AboutScreen(),
                    ),
                    GoRoute(
                      path: 'support',
                      builder: (context, state) => const SupportTicketsScreen(),
                      routes: [
                        GoRoute(
                          path: 'new',
                          builder: (context, state) =>
                              const SupportCreateScreen(),
                        ),
                        GoRoute(
                          path: ':ticketId',
                          builder: (context, state) => SupportThreadScreen(
                            ticketId: state.pathParameters['ticketId'] ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.tariffs,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const TariffsScreen(),
        ),
        GoRoute(
          path: AppRoutes.preferences,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const PreferencesScreen(),
        ),
        GoRoute(
          path: AppRoutes.payment,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const PaymentScreen(),
        ),
        GoRoute(
          path: AppRoutes.confirmation,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const ConfirmationScreen(),
        ),
        GoRoute(
          path: AppRoutes.activeTrip,
          parentNavigatorKey: _rootKey,
          pageBuilder: (context, state) => _calmPage(
            state,
            const ActiveTripScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.paymentReceipt,
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final args = state.extra is PaymentReceiptArgs
                ? state.extra! as PaymentReceiptArgs
                : const PaymentReceiptArgs(
                    orderId: '—',
                    fromAddress: '',
                    toAddress: '',
                  );
            return PaymentReceiptScreen(args: args);
          },
        ),
        GoRoute(
          path: AppRoutes.rateTrip,
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final args = state.extra is RateTripArgs
                ? state.extra! as RateTripArgs
                : const RateTripArgs(orderId: '—');
            return RateTripScreen(args: args);
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Страница не найдена: ${state.uri}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static Page<void> _calmPage(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static String? _redirect(AuthProvider auth, GoRouterState state) {
    final loc = state.matchedLocation;

    if (!auth.loaded) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    if (loc == AppRoutes.splash) {
      return null;
    }

    final onAuthFlow = loc == AppRoutes.auth || loc == AppRoutes.authName;

    if (!auth.isAuthenticated) {
      if (onAuthFlow) return null;
      return AppRoutes.auth;
    }

    if (auth.needsName) {
      return loc == AppRoutes.authName ? null : AppRoutes.authName;
    }

    if (!auth.onboardingCompleted) {
      if (loc == AppRoutes.onboarding) return null;
      if (onAuthFlow) return AppRoutes.onboarding;
      return AppRoutes.onboarding;
    }

    if (onAuthFlow) {
      return AppRoutes.home;
    }

    if (loc == AppRoutes.onboarding) {
      return AppRoutes.home;
    }

    return null;
  }
}
