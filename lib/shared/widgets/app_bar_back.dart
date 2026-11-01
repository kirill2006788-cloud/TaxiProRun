import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Единый AppBar с кнопкой «назад» для экранов бронирования.
PreferredSizeWidget appBarWithBack(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  VoidCallback? onBack,
}) {
  return AppBar(
    title: Text(title),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Назад',
      onPressed: onBack ?? () => context.pop(),
    ),
    actions: actions,
  );
}
