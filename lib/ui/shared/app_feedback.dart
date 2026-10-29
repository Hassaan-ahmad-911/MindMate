import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showMindMateSnackBar(String title, String message) {
  final BuildContext? context = Get.context;
  if (context == null) {
    debugPrint('$title: $message');
    return;
  }

  try {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      );
  } catch (_) {
    debugPrint('$title: $message');
  }
}

/// A small "Saved" toast after a setting changes.
void showSavedToast() {
  final BuildContext? context = Get.context;
  if (context == null) {
    return;
  }
  try {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: 140,
          duration: const Duration(milliseconds: 1200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.check_rounded, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text('Saved', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
  } catch (_) {}
}
