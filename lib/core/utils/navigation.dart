import 'package:get/get.dart';

/// Leaves the current page, returning [result] to the caller.
///
/// Use this instead of `Get.back()`: in GetX 4, `Get.back()` only closes an
/// open snackbar and stays on the page, which breaks every "save → show
/// success → go back" flow. Popping the navigator directly also keeps the
/// success message visible on the previous screen.
void popPage<T>([T? result]) => Get.key.currentState?.maybePop<T>(result);
