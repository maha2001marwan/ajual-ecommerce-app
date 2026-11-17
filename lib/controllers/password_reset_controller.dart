import 'dart:async';

import 'package:get/get.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../repositories/password_reset_repository.dart';

/// State for the Forgot Password → Verify Code → New Password flow. It lives
/// as long as the Forgot Password route, so every attempt starts clean.
class PasswordResetController extends GetxController {
  PasswordResetController(this._repository);

  static const int codeLength = 4;

  final PasswordResetRepository _repository;

  final RxString email = ''.obs;
  final RxBool isBusy = false.obs;
  final RxInt resendSecondsLeft = 0.obs;

  /// Demo mode only (Spark plan): the code to show on screen.
  final RxnString demoCode = RxnString();

  bool get isDemo => _repository.isDemo;

  String? _resetToken;
  Timer? _countdown;

  bool get canResend => resendSecondsLeft.value == 0 && !isBusy.value;

  /// Sends the first code. Returns `true` when the Verify Code screen should
  /// open, which includes the case where a code was sent moments ago.
  Future<bool> sendCode(String address) => _requestCode(address.trim());

  Future<bool> resendCode() async {
    if (!canResend || email.value.isEmpty) return false;
    return _requestCode(email.value, isResend: true);
  }

  Future<bool> _requestCode(String address, {bool isResend = false}) async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      final cooldown = await _repository.requestCode(address);
      email.value = address;
      demoCode.value = _repository.demoCode;
      _resetToken = null;
      _startCountdown(cooldown);
      if (isResend) {
        AppFeedback.success('We sent a new code to $address', title: 'Code sent');
      }
      return true;
    } on RetryLaterException catch (error) {
      _startCountdown(error.retryAfter);
      if (error.isCooldown) {
        // The previous code is still valid, so the user can go ahead and use it.
        email.value = address;
        AppFeedback.info(error.message, title: 'Code already sent');
        return true;
      }
      AppFeedback.error(error, title: 'Too many requests');
      return false;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not send code');
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> verifyCode(String code) async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      _resetToken = await _repository.verifyCode(
        email: email.value,
        code: code,
      );
      return true;
    } catch (error) {
      AppFeedback.error(error, title: 'Verification failed');
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  /// `null` on failure, `true` when the server changed the password, `false`
  /// in demo mode (the emailed Firebase link completes the change).
  Future<bool?> resetPassword(String newPassword) async {
    final token = _resetToken;
    if (token == null) {
      AppFeedback.error(
        const AppException('Verify the code from your email first.'),
      );
      return null;
    }
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      final changed = await _repository.resetPassword(
        email: email.value,
        resetToken: token,
        newPassword: newPassword,
      );
      _resetToken = null;
      demoCode.value = null;
      return changed;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not reset password');
      return null;
    } finally {
      isBusy.value = false;
    }
  }

  void _startCountdown(Duration duration) {
    _countdown?.cancel();
    resendSecondsLeft.value = duration.inSeconds;
    if (duration.inSeconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSecondsLeft.value <= 1) {
        resendSecondsLeft.value = 0;
        timer.cancel();
      } else {
        resendSecondsLeft.value--;
      }
    });
  }

  @override
  void onClose() {
    _countdown?.cancel();
    super.onClose();
  }
}
