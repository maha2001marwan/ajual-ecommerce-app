import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_exception.dart';

/// Central place for turning caught errors into user feedback (SnackBars),
/// styled to match the black & white design.
class AppFeedback {
  AppFeedback._();

  static void _show(
    String title,
    String message, {
    required IconData icon,
    required Color accent,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF111111),
      colorText: Colors.white,
      icon: Icon(icon, color: accent),
      shouldIconPulse: true,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: duration,
      animationDuration: const Duration(milliseconds: 380),
      forwardAnimationCurve: Curves.easeOutBack,
      isDismissible: true,
      dismissDirection: DismissDirection.up,
    );
  }

  static void success(String message, {String title = 'Success'}) => _show(
    title,
    message,
    icon: Icons.check_circle_rounded,
    accent: const Color(0xFF1FB57A),
  );

  static void error(Object error, {String title = 'Something went wrong'}) {
    final AppException exception = AppException.from(error);
    _show(
      title,
      exception.message,
      icon: Icons.error_rounded,
      accent: const Color(0xFFE53935),
      duration: const Duration(seconds: 4),
    );
  }

  static void info(String message, {String title = 'Info'}) => _show(
    title,
    message,
    icon: Icons.info_rounded,
    accent: const Color(0xFF3B82F6),
  );

  /// Explains that a feature runs on demo data on the free Firebase plan.
  static void demo(String message, {String title = 'Demo feature'}) => _show(
    title,
    message,
    icon: Icons.science_rounded,
    accent: const Color(0xFFFFB400),
    duration: const Duration(seconds: 4),
  );
}

/// Runs an async [action], converting thrown errors into user feedback.
/// Returns `true` when the action completed without throwing.
Future<bool> guard(
  Future<void> Function() action, {
  String? errorTitle,
  bool report = true,
}) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (report) {
      AppFeedback.error(error, title: errorTitle ?? 'Something went wrong');
    }
    return false;
  }
}
