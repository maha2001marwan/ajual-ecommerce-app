import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/password_reset_controller.dart';
import '../../core/animations/motion.dart';
import 'new_password_screen.dart';
import 'widgets/auth_ui.dart';
import 'widgets/otp_code_input.dart';

/// Verify Code (design page 8).
/// Animations: staggered entrance, demo-code banner sliding in, boxes shake on
/// a wrong code, rolling resend countdown.
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final PasswordResetController reset = Get.find<PasswordResetController>();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  bool _hasError = false;
  int _shake = 0;

  static const int _length = PasswordResetController.codeLength;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// The input is disabled while a request runs, so focus is requested once
  /// the next frame has re-enabled it.
  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  void _fail() {
    HapticFeedback.heavyImpact();
    setState(() {
      _hasError = true;
      _shake++;
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text;
    if (code.length != _length) {
      _fail();
      _refocus();
      return;
    }
    FocusScope.of(context).unfocus();
    final verified = await reset.verifyCode(code);
    if (!mounted) return;
    if (verified) {
      // The code is single-use, so this screen is replaced rather than kept.
      Get.off(
        () => const NewPasswordScreen(),
        transition: Transition.cupertino,
      );
    } else {
      _fail();
      _codeController.clear();
      _refocus();
    }
  }

  Future<void> _resend() async {
    final sent = await reset.resendCode();
    if (sent && mounted) {
      setState(() => _hasError = false);
      _codeController.clear();
      _refocus();
    }
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: Obx(() {
        final busy = reset.isBusy.value;
        final secondsLeft = reset.resendSecondsLeft.value;
        final demoCode = reset.demoCode.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggered([
            AuthHeader(
              title: 'Verify Code',
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Enter the code we just sent to email\n',
                    ),
                    TextSpan(
                      text: reset.email.value,
                      style: AuthText.input.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              child: demoCode == null
                  ? const SizedBox(height: 60, width: double.infinity)
                  : _DemoCodeBanner(code: demoCode),
            ),
            ShakeX(
              trigger: _shake,
              child: OtpCodeInput(
                controller: _codeController,
                focusNode: _codeFocus,
                length: _length,
                enabled: !busy,
                hasError: _hasError,
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
                onCompleted: (_) => _verify(),
              ),
            ),
            const SizedBox(height: 32),
            AuthPrimaryButton(
              label: 'Verify',
              loading: busy,
              onPressed: _verify,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Didn’t receive code? ', style: AuthText.subtitle),
                InkWell(
                  onTap: reset.canResend ? _resend : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    child: secondsLeft > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Resend in ',
                                style: AuthText.link.copyWith(
                                  color: AuthColors.muted,
                                ),
                              ),
                              RollingText(
                                _formatSeconds(secondsLeft),
                                up: false,
                                style: AuthText.link.copyWith(
                                  color: AuthColors.muted,
                                ),
                              ),
                            ],
                          )
                        : const Text('Resend code', style: AuthText.link),
                  ),
                ),
              ],
            ),
          ], stepMs: 50),
        );
      }),
    );
  }
}

/// Spark-plan demo: the code that would normally be emailed.
class _DemoCodeBanner extends StatelessWidget {
  const _DemoCodeBanner({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      offset: const Offset(0, -0.3),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE2A0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: Color(0xFF9A6B00)),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Demo code: '),
                    TextSpan(
                      text: code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '\nWe also emailed you Firebase’s reset link — use it to actually change the password on the free plan.',
                      style: TextStyle(fontSize: 12, color: AuthColors.muted),
                    ),
                  ],
                ),
                style: AuthText.input,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
