import 'package:get/get.dart';

enum ShellTab { home, categories, wishlist, account }

/// Selected bottom-navigation tab, so any screen can jump to a tab.
class ShellController extends GetxController {
  final Rx<ShellTab> tab = ShellTab.home.obs;

  /// Bumped when the user re-taps the active tab (scroll to top).
  final RxInt reselect = 0.obs;

  void select(ShellTab value) {
    if (tab.value == value) {
      reselect.value++;
    } else {
      tab.value = value;
    }
  }

  /// Pops back to the shell and opens [value].
  void open(ShellTab value) {
    Get.until((route) => route.isFirst);
    tab.value = value;
  }
}
