import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/broadcast_banner.dart';

/// Нижняя навигация клиента: только Главная и Профиль.
///
/// История поездок перенесена в профиль, чтобы заказ такси начинался сразу
/// с карты и не расползался по лишним вкладкам.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final goldAccent =
        context.isDarkTheme ? AppColors.gold : AppColors.goldDark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: KeyedSubtree(
              key: ValueKey<int>(currentIndex),
              child: widget.navigationShell,
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BroadcastBanner(audience: 'clients'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: context.palette.cardShadow,
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _onDestinationSelected,
          animationDuration: const Duration(milliseconds: 240),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: goldAccent),
              label: 'Главная',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: goldAccent),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
