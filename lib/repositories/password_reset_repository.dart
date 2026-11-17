import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';

/// Forgot Password → Verify Code → New Password.
///
/// * **Blaze** ([AppConfig.useCloudFunctions]): the original Cloud Functions
///   email a 4-digit code and change the password server-side.
/// * **Spark** (default): Firebase's free `sendPasswordResetEmail` sends the
///   official reset link — that link is what actually changes the password.
///   The 4-digit code screens still work, in demo mode: the code is generated
///   on the device and shown in a banner, because emailing custom codes needs
///   a server.
class PasswordResetRepository {
  PasswordResetRepository({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFunctions? _functions;
  final math.Random _random = math.Random.secure();

  String? _demoCode;
  String? _demoEmail;

  bool get isDemo => !AppConfig.useCloudFunctions;

  /// Code to show on screen in demo mode.
  String? get demoCode => _demoCode;

  FirebaseFunctions get _fn => _functions ?? FirebaseFunctions.instance;

  /// Sends the reset email/code and returns how long to wait before a resend.
  Future<Duration> requestCode(String email) async {
    if (isDemo) {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim());
      } on FirebaseAuthException catch (error) {
        // Don't reveal whether the account exists.
        if (error.code != 'user-not-found') throw AppException.from(error);
      } catch (error) {
        throw AppException.from(error);
      }
      _demoEmail = email.trim().toLowerCase();
      _demoCode = List.generate(4, (_) => _random.nextInt(10)).join();
      return const Duration(seconds: 60);
    }
    try {
      final response = await _fn
          .httpsCallable('requestPasswordResetCode')
          .call({'email': email.trim()});
      final data = response.data;
      final seconds = data is Map ? data['resendAfterSeconds'] : null;
      return Duration(seconds: seconds is num ? seconds.ceil() : 60);
    } catch (error) {
      throw _map(error);
    }
  }

  /// Returns the reset token that authorises [resetPassword].
  Future<String> verifyCode({required String email, required String code}) async {
    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_demoEmail != email.trim().toLowerCase() || _demoCode != code.trim()) {
        throw const AppException('The code is incorrect. Check it and try again.');
      }
      return 'demo-token';
    }
    try {
      final response = await _fn
          .httpsCallable('verifyPasswordResetCode')
          .call({'email': email.trim(), 'code': code.trim()});
      final data = response.data;
      final token = data is Map ? data['resetToken'] : null;
      if (token is! String || token.isEmpty) {
        throw const AppException('The server returned an invalid response.');
      }
      return token;
    } catch (error) {
      throw _map(error);
    }
  }

  /// Returns `true` when the password was changed on the server, `false` in
  /// demo mode (the emailed link completes the change).
  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _demoCode = null;
      return false;
    }
    try {
      await _fn.httpsCallable('completePasswordReset').call({
        'email': email.trim(),
        'resetToken': resetToken,
        'newPassword': newPassword,
      });
      return true;
    } catch (error) {
      throw _map(error);
    }
  }

  static AppException _map(Object error) {
    if (error is FirebaseFunctionsException &&
        error.code == 'resource-exhausted') {
      final details = error.details;
      final seconds = details is Map ? details['retryAfterSeconds'] : null;
      if (seconds is num) {
        return RetryLaterException(
          error.message ?? 'Please try again later.',
          retryAfter: Duration(seconds: seconds.ceil()),
          isCooldown: details is Map && details['reason'] == 'cooldown',
          code: error.code,
          cause: error,
        );
      }
    }
    return AppException.from(error);
  }
}
