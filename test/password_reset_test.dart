import 'package:ajual/Screens/auth/widgets/otp_code_input.dart';
import 'package:ajual/controllers/password_reset_controller.dart';
import 'package:ajual/core/errors/app_exception.dart';
import 'package:ajual/repositories/password_reset_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// In-memory stand-in for the Cloud Functions backend.
class FakePasswordResetRepository implements PasswordResetRepository {
  Object? requestError;
  String validCode = '1234';
  final List<String> requestedEmails = [];
  String? lastResetToken;
  String? lastPassword;

  @override
  bool get isDemo => false;

  @override
  String? get demoCode => null;

  @override
  Future<Duration> requestCode(String email) async {
    requestedEmails.add(email);
    final error = requestError;
    if (error != null) throw error;
    return const Duration(seconds: 60);
  }

  @override
  Future<String> verifyCode({
    required String email,
    required String code,
  }) async {
    if (code != validCode) {
      throw const AppException('That code is incorrect. Please try again.');
    }
    return 'token-for-$email';
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    lastResetToken = resetToken;
    lastPassword = newPassword;
    return true;
  }
}

void main() {
  group('PasswordResetController', () {
    late FakePasswordResetRepository repository;
    late PasswordResetController controller;

    // AppFeedback shows GetX snackbars, which need a mounted GetMaterialApp.
    Future<void> pumpApp(WidgetTester tester) async {
      Get.testMode = true;
      repository = FakePasswordResetRepository();
      controller = PasswordResetController(repository);
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    }

    Future<void> drainSnackbars(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
      controller.onClose();
    }

    testWidgets('sending a code stores the email and starts the cooldown', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(await controller.sendCode('  user@example.com '), isTrue);
      expect(controller.email.value, 'user@example.com');
      expect(repository.requestedEmails, ['user@example.com']);
      expect(controller.resendSecondsLeft.value, 60);
      expect(controller.canResend, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(controller.resendSecondsLeft.value, 59);
      controller.onClose();
    });

    testWidgets('a cooldown still lets the user enter the recent code', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.requestError = const RetryLaterException(
        'Please wait 30 seconds before requesting a new code.',
        retryAfter: Duration(seconds: 30),
        isCooldown: true,
      );

      expect(await controller.sendCode('user@example.com'), isTrue);
      expect(controller.email.value, 'user@example.com');
      expect(controller.resendSecondsLeft.value, 30);
      await drainSnackbars(tester);
    });

    testWidgets('the hourly limit keeps the user on the email step', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.requestError = const RetryLaterException(
        'Too many codes requested. Please try again later.',
        retryAfter: Duration(minutes: 40),
      );

      expect(await controller.sendCode('user@example.com'), isFalse);
      expect(controller.email.value, isEmpty);
      await drainSnackbars(tester);
    });

    testWidgets('a verified code authorises the password reset', (
      tester,
    ) async {
      await pumpApp(tester);
      await controller.sendCode('user@example.com');

      expect(await controller.verifyCode('0000'), isFalse);
      expect(await controller.verifyCode('1234'), isTrue);
      expect(await controller.resetPassword('new-secret'), isTrue);
      expect(repository.lastResetToken, 'token-for-user@example.com');
      expect(repository.lastPassword, 'new-secret');

      // The token is single use.
      expect(await controller.resetPassword('again'), isNull);
      await drainSnackbars(tester);
    });
  });

  group('OtpCodeInput', () {
    testWidgets('accepts digits only and reports a complete code', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      String? completed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpCodeInput(
              controller: controller,
              focusNode: focusNode,
              onCompleted: (code) => completed = code,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '1a2');
      await tester.pump();
      expect(controller.text, '12');
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(completed, isNull);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(controller.text, '1234');
      expect(completed, '1234');

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focusNode.dispose();
    });
  });
}
