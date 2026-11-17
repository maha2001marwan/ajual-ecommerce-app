import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A platform-agnostic exception used across the app so the UI never has to
/// know about Firebase-specific error types.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  /// Codes Firebase reports when the user closes a sign-in sheet or popup.
  static const Set<String> _cancellationCodes = {
    'canceled',
    'cancelled',
    'web-context-canceled',
    'web-context-cancelled',
    'popup-closed-by-user',
    'cancelled-popup-request',
    'user-cancelled',
  };

  /// True when the user dismissed the flow themselves, so no error is shown.
  bool get isCancelled => _cancellationCodes.contains(code);

  /// Maps any arbitrary thrown object (usually a [FirebaseException]) into a
  /// friendly [AppException] with a human readable message.
  factory AppException.from(Object error) {
    if (error is AppException) return error;

    if (error is FirebaseAuthException) {
      return AppException(_authMessage(error), code: error.code, cause: error);
    }

    if (error is FirebaseFunctionsException) {
      return AppException(
        _functionMessage(error),
        code: error.code,
        cause: error,
      );
    }

    if (error is FirebaseException) {
      return AppException(
        _firestoreMessage(error),
        code: error.code,
        cause: error,
      );
    }

    return AppException(error.toString(), cause: error);
  }

  static String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'weak-password':
        return 'Please choose a stronger password (min 6 characters).';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'invalid-phone-number':
        return 'The phone number is not valid.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Sign in with the method you used before.';
      case 'popup-blocked':
        return 'Allow pop-ups for this site to continue.';
      case 'web-context-already-presented':
        return 'A sign-in window is already open.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  static String _firestoreMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Please retry.';
      case 'not-found':
        return 'The requested data could not be found.';
      case 'already-exists':
        return 'That record already exists.';
      case 'failed-precondition':
        return 'A required index is missing. Please try again later.';
      default:
        return error.message ?? 'A database error occurred.';
    }
  }

  static String _functionMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in before placing an order.';
      case 'invalid-argument':
        return error.message ?? 'Check the order details and try again.';
      case 'failed-precondition':
        return error.message ?? 'One or more products are no longer available.';
      case 'permission-denied':
        return 'You do not have permission to place this order.';
      case 'resource-exhausted':
        return error.message ?? 'The order contains too many items.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The service is temporarily unavailable. Please retry.';
      case 'internal':
        return 'Something went wrong on our side. Please try again.';
      default:
        return error.message ?? 'The order could not be completed.';
    }
  }

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

/// Raised when the backend rate-limits a request. [retryAfter] tells the UI how
/// long to wait; [isCooldown] is true for the short per-request cooldown (as
/// opposed to an hourly limit).
class RetryLaterException extends AppException {
  const RetryLaterException(
    super.message, {
    required this.retryAfter,
    this.isCooldown = false,
    super.code,
    super.cause,
  });

  final Duration retryAfter;
  final bool isCooldown;
}
