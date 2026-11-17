import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get/get.dart';

import '../Service/shared_pref.dart';
import 'auth_controller.dart';

/// Remembers whether the welcome carousel has been shown on this device.
/// Anyone who has signed in before skips it, even after signing out.
class OnboardingController extends GetxController {
  OnboardingController(
    this._auth, {
    required bool completed,
    StorageServiceShared? storage,
  })  : completed = completed.obs,
        _storage = storage ?? StorageServiceShared.instance;

  final AuthController _auth;
  final StorageServiceShared _storage;
  final RxBool completed;

  Worker? _authWorker;

  @override
  void onInit() {
    super.onInit();
    _authWorker = ever<fb.User?>(_auth.user, (user) {
      if (user != null) complete();
    });
    if (_auth.isAuthenticated) complete();
  }

  Future<void> complete() async {
    if (completed.value) return;
    completed.value = true;
    try {
      await _storage.setOnboardingSeen();
    } catch (_) {
      // Worst case the carousel shows once more on the next launch.
    }
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }
}
