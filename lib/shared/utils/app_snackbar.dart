import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? AppColors.error : AppColors.gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
}
