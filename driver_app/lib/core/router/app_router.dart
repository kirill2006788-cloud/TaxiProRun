import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/active_order/active_order_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/info/info_screens.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/registration/registration_status_screen.dart';
import '../../features/registration/registration_wizard_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/support/support_screens.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const registration = '/registration';
  static const registrationStatus = '/registration-status';
  static const orders = '/orders';
  static const history = '/history';
  static const profile = '/profile';
  static const activeOrder = '/active-order';
  static const settings = '/settings';
  static const about = '/about';
  static const privacy = '/privacy';
  static const support = '/support';
  static const supportNew = '/support/new';
  static String supportDetail(String id) => '/support/$id';
}

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter({
    required SettingsProvider settings,
    required AuthProvider auth,
    required DriverProvider driver,
  }) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.orders,
      refreshListenable: Listenable.merge([settings, auth, driver]),
      redirect: (context, state) {
        if (!settings.initialized || !auth.initialized) {
          return null;
        }

        final loggedIn = auth.isLoggedIn;
        final location = state.matchedLocation;
        final onLogin = location == AppRoutes.login;
        final onRegistration = location == AppRoutes.registration;
        final onRegistrationStatus = location == AppRoutes.registrationStatus;

        if (!loggedIn) {
          if (onLogin) return null;
          return AppRoutes.login;
        }

        if (onLogin) {
          return _registrationRedirect(driver.profile.registrationStatus);
        }

        final reg = normalizeRegistrationStatus(driver.profile.registrationStatus);
        if (reg == 'incomplete') {
          if (onRegistration || onRegistrationStatus) return null;
          return AppRoutes.registration;
        }
        if (reg == 'pending') {
          if (onRegistrationStatus) return null;
          return AppRoutes.registrationStatus;
        }
        if (reg == 'rejected') {
          if (onRegistration || onRegistrationStatus) return null;
          return AppRoutes.registrationStatus;
        }
        if (driver.profile.registrationBlocked || reg == 'blocked') {
          if (onRegistrationStatus) return null;
          return AppRoutes.registrationStatus;
        }
        if (reg == 'completed') {
          if (onLogin || onRegistration || onRegistrationStatus) {
            return AppRoutes.orders;
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.registration,
          builder: (context, state) => const RegistrationWizardScreen(),
        ),
        GoRoute(
          path: AppRoutes.registrationStatus,
          builder: (context, state) => const RegistrationStatusScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.orders,
                  builder: (context, state) => const OrdersScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.history,
                  builder: (context, state) => const HistoryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.activeOrder,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const ActiveOrderScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.about,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: AppRoutes.privacy,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => LegalDocumentScreen.privacy(),
        ),
        GoRoute(
          path: AppRoutes.support,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const SupportScreen(),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootKey,
              builder: (context, state) => const SupportCreateScreen(),
            ),
            GoRoute(
              path: ':ticketId',
              parentNavigatorKey: _rootKey,
              builder: (context, state) => SupportThreadScreen(
                ticketId: state.pathParameters['ticketId'] ?? '',
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Страница не найдена: ${state.uri}')),
      ),
    );
  }

  static String? _registrationRedirect(String status) {
    return switch (normalizeRegistrationStatus(status)) {
      'completed' => AppRoutes.orders,
      'pending' || 'rejected' || 'blocked' => AppRoutes.registrationStatus,
      _ => AppRoutes.registration,
    };
  }
}
