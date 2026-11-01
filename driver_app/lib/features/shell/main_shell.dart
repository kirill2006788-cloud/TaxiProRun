import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/broadcast_banner.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final t = context.tokens;
    final selected = t.isDark ? AppColors.gold : AppColors.goldDark;

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
                  DriverBroadcastBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: _onTap,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: selected,
            unselectedItemColor: t.textMuted,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.navigation_rounded, color: selected),
                label: 'Главная',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_outlined),
                activeIcon: Icon(Icons.history, color: selected),
                label: 'Поездки',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person, color: selected),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
