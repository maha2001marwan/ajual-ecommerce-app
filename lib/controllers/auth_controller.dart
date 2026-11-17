import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get/get.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/user_repository.dart';

/// Owns authentication state, the current user's Firestore profile and the
/// one-time data seeding that runs after the first successful sign-in.
class AuthController extends GetxController {
  AuthController(
    this._authRepository,
    this._userRepository,
    this._productRepository,
  );

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ProductRepository _productRepository;

  final Rx<fb.User?> user = Rx<fb.User?>(null);
  final Rxn<UserProfile> profile = Rxn<UserProfile>();
  final RxBool isInitializing = true.obs;
  final RxBool isProfileLoading = false.obs;
  final RxBool profileLoadFailed = false.obs;
  final RxBool isBusy = false.obs;

  /// Set once Firebase sends the SMS code during phone verification.
  final RxString phoneVerificationId = ''.obs;

  StreamSubscription<fb.User?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;
  final List<Future<void> Function()> _beforeSignOut = [];
  bool _seeded = false;

  UserProfile? get userProfile => profile.value;
  bool get isAuthenticated => user.value != null;

  @override
  void onInit() {
    super.onInit();
    _authSubscription = _authRepository.authStateChanges().listen(
      _handleAuthStateChanged,
      onError: (Object error) {
        // Do not leave AuthGate on the splash forever if Firebase Auth's
        // initial state stream fails. Let the user reach sign-in and report it.
        user.value = null;
        profile.value = null;
        isProfileLoading.value = false;
        profileLoadFailed.value = false;
        isInitializing.value = false;
        AppFeedback.error(error, title: 'Could not restore sign-in');
      },
    );
  }

  Future<void> _handleAuthStateChanged(fb.User? currentUser) async {
    user.value = currentUser;
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    if (currentUser == null) {
      profile.value = null;
      isProfileLoading.value = false;
      profileLoadFailed.value = false;
      isInitializing.value = false;
      return;
    }

    isProfileLoading.value = true;
    profileLoadFailed.value = false;
    isInitializing.value = false;

    try {
      profile.value = await _userRepository.ensureProfile(currentUser);
      _profileSubscription = _userRepository
          .watchProfile(currentUser.uid)
          .listen((value) {
            if (value != null) profile.value = value;
          });
    } catch (error) {
      profileLoadFailed.value = true;
      AppFeedback.error(error);
    } finally {
      isProfileLoading.value = false;
    }

    unawaited(
      _seedSharedDataIfNeeded().catchError((Object error) {
        AppFeedback.error(error, title: 'Could not load shared data');
      }),
    );
  }

  /// Shared (non user-specific) collections are only written once the user is
  /// authenticated because security rules require an authenticated request.
  Future<void> _seedSharedDataIfNeeded() async {
    if (_seeded) return;
    await _productRepository.seedIfNeeded();
    _seeded = true;
  }

  Future<void> refreshProfile() async {
    final currentUser = user.value;
    if (currentUser == null || isProfileLoading.value) return;

    isProfileLoading.value = true;
    profileLoadFailed.value = false;
    try {
      profile.value = await _userRepository.ensureProfile(currentUser);
      await _profileSubscription?.cancel();
      _profileSubscription = _userRepository
          .watchProfile(currentUser.uid)
          .listen(
            (value) {
              if (value != null) profile.value = value;
            },
            onError: (Object error) =>
                AppFeedback.error(error, title: 'Profile update failed'),
          );
    } catch (error) {
      profileLoadFailed.value = true;
      AppFeedback.error(error, title: 'Could not load profile');
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
    String errorTitle = 'Something went wrong',
  }) async {
    if (isBusy.value) return;
    try {
      isBusy.value = true;
      await action();
      if (successMessage != null) AppFeedback.success(successMessage);
    } catch (error) {
      if (!AppException.from(error).isCancelled) {
        AppFeedback.error(error, title: errorTitle);
      }
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> signInAnonymously() => _run(
    () async => _authRepository.signInAnonymously(),
    errorTitle: 'Guest sign-in failed',
  );

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _run(
    () async =>
        _authRepository.signInWithEmail(email: email, password: password),
    errorTitle: 'Sign-in failed',
  );

  Future<void> signInWithGoogle() => _run(
    () async => _authRepository.signInWithGoogle(),
    errorTitle: 'Google sign-in failed',
  );

  Future<void> signInWithApple() => _run(
    () async => _authRepository.signInWithApple(),
    errorTitle: 'Apple sign-in failed',
  );

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) => _run(
    () async => _authRepository.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    ),
    successMessage: 'Account created',
    errorTitle: 'Sign-up failed',
  );

  Future<void> sendPasswordResetEmail(String email) => _run(
    () async => _authRepository.sendPasswordResetEmail(email),
    successMessage: 'Password reset email sent',
    errorTitle: 'Could not send reset email',
  );

  /// Starts the SMS flow. Returns `true` when the user must enter a code on the
  /// OTP screen, or `false` when the flow completed automatically (Android
  /// instant verification) or failed.
  Future<bool> startPhoneVerification(String phoneNumber) async {
    if (isBusy.value) return false;
    isBusy.value = true;

    final completer = Completer<bool>();
    try {
      await _authRepository.startPhoneVerification(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          phoneVerificationId.value = verificationId;
          if (!completer.isCompleted) completer.complete(true);
        },
        onAutoVerified: (credential) async {
          try {
            await _authRepository.signInWithPhoneCredential(credential);
          } catch (error) {
            AppFeedback.error(error);
          }
          if (!completer.isCompleted) completer.complete(false);
        },
        onError: (fb.FirebaseAuthException error) {
          AppFeedback.error(error, title: 'Phone verification failed');
          if (!completer.isCompleted) completer.complete(false);
        },
      );
    } catch (error) {
      AppFeedback.error(error, title: 'Could not send code');
      if (!completer.isCompleted) completer.complete(false);
    }

    final needsOtp = await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => phoneVerificationId.value.isNotEmpty,
    );
    isBusy.value = false;
    return needsOtp;
  }

  Future<bool> confirmPhoneCode(String smsCode) async {
    var confirmed = false;
    await _run(() async {
      await _authRepository.confirmPhoneCode(
        verificationId: phoneVerificationId.value,
        smsCode: smsCode,
      );
      confirmed = true;
    }, errorTitle: 'Invalid code');
    return confirmed;
  }

  Future<void> updateDisplayName(String displayName) => _run(
    () async {
      final current = user.value;
      if (current == null) return;
      await _authRepository.updateDisplayName(displayName);
      await _userRepository.updateDisplayName(current.uid, displayName);
      final existing = profile.value;
      if (existing != null) {
        profile.value = existing.copyWith(displayName: displayName.trim());
      }
    },
    successMessage: 'Profile updated',
    errorTitle: 'Could not update profile',
  );

  /// Saves the Edit Profile form. Returns `true` on success.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneCode,
    required String phoneNumber,
    String? gender,
    DateTime? birthday,
    int? avatarId,
  }) async {
    var saved = false;
    await _run(
      () async {
        final current = user.value;
        if (current == null) return;
        final name = '${firstName.trim()} ${lastName.trim()}'.trim();
        await _userRepository.updateProfile(
          current.uid,
          firstName: firstName,
          lastName: lastName,
          phoneCode: phoneCode,
          phoneNumber: phoneNumber,
          gender: gender,
          birthday: birthday,
          avatarId: avatarId,
        );
        if (name.isNotEmpty) await _authRepository.updateDisplayName(name);
        final existing = profile.value;
        if (existing != null) {
          profile.value = existing.copyWith(
            displayName: name,
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            phoneCode: phoneCode,
            phoneNumber: phoneNumber.trim(),
            gender: gender,
            birthday: birthday,
            avatarId: avatarId,
          );
        }
        saved = true;
      },
      successMessage: 'Profile updated',
      errorTitle: 'Could not update profile',
    );
    return saved;
  }

  /// Registers cleanup that must run while the user is still signed in:
  /// security rules reject the user's writes once sign-out completes.
  void addBeforeSignOut(Future<void> Function() callback) =>
      _beforeSignOut.add(callback);

  Future<void> signOut() => _run(() async {
    for (final callback in List.of(_beforeSignOut)) {
      try {
        await callback();
      } catch (_) {
        // Cleanup is best effort and must never block signing out.
      }
    }
    await _authRepository.signOut();
  }, errorTitle: 'Sign-out failed');

  Future<void> deleteAccount() => _run(
    () async => _authRepository.deleteAccount(),
    errorTitle: 'Could not delete account',
  );

  @override
  void onClose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.onClose();
  }
}
