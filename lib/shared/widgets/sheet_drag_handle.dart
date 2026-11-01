import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Single modal/sheet drag handle — one per sheet, no duplicates.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final handle = Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: p.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Center(child: handle),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Center(
          child: SizedBox(
            width: 72,
            height: 20,
            child: Center(child: handle),
          ),
        ),
      ),
    );
  }
}
