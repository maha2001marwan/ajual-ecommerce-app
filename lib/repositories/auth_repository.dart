import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/errors/app_exception.dart';

/// Thin wrapper around [FirebaseAuth] so the rest of the app never talks to the
/// Firebase SDK directly and every failure surfaces as an [AppException].
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  /// Emits on every sign-in / sign-out. Because Firebase persists the session,
  /// this is what drives the persistent auth state in the UI.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User> _wrap(Future<User?> Function() action) async {
    try {
      final user = await action();
      if (user == null) {
        throw const AppException('Authentication failed. Please try again.');
      }
      return user;
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<User> signInAnonymously() =>
      _wrap(() async => (await _auth.signInAnonymously()).user);

  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = await _wrap(
      () async => (await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      )).user,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await updateDisplayName(displayName.trim());
    }
    return user;
  }

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _wrap(() async => (await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      )).user);

  /// Google sign-in through Firebase's provider flow (native sheet on iOS,
  /// Custom Tab on Android, popup on web), so no extra plugin is needed.
  Future<User> signInWithGoogle() {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    return _signInWithProvider(provider);
  }

  Future<User> signInWithApple() {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _signInWithProvider(provider);
  }

  Future<User> _signInWithProvider(AuthProvider provider) => _wrap(
    () async => (kIsWeb
            ? await _auth.signInWithPopup(provider)
            : await _auth.signInWithProvider(provider))
        .user,
  );

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (error) {
      throw AppException.from(error);
    }
  }

  /// Starts the SMS verification flow. Results are delivered through callbacks.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onError,
    Duration timeout = const Duration(seconds: 60),
    int? forceResendingToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: onAutoVerified,
        verificationFailed: onError,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<User> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) {
    return _wrap(() async {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return (await _auth.signInWithCredential(credential)).user;
    });
  }

  Future<User> signInWithPhoneCredential(PhoneAuthCredential credential) =>
      _wrap(() async => (await _auth.signInWithCredential(credential)).user);

  /// Upgrades an anonymous account to an email/password account while keeping
  /// the same uid (and therefore all of its Firestore data).
  Future<User> linkEmailToCurrentUser({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException('You must be signed in to link an account.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      return (await user.linkWithCredential(credential)).user!;
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName.trim());
      await _auth.currentUser?.reload();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
