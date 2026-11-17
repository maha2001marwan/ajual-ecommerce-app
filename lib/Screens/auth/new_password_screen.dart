import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/password_reset_controller.dart';
import '../../core/animations/effects.dart';
import '../../core/animations/motion.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/validators.dart';
import 'widgets/auth_ui.dart';

/// "Create New Password" (design page 9).
/// Animations: staggered entrance, match indicator morph, shake on invalid
/// input, success sheet with an animated check.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final PasswordResetController reset = Get.find<PasswordResetController>();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  int _shake = 0;
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkMatch);
    _confirmController.addListener(_checkMatch);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _checkMatch() {
    final value =
        _confirmController.text.isNotEmpty &&
        _confirmController.text == _passwordController.text &&
        _passwordController.text.length >= 6;
    if (value != _matches) setState(() => _matches = value);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    final email = reset.email.value;
    final password = _passwordController.text;
    final changed = await reset.resetPassword(password);
    if (changed == null || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ResetDoneSheet(serverChanged: changed),
    );

    // Back to the root (the Sign In screen).
    Get.until((route) => route.isFirst);
    if (changed) {
      AppFeedback.success('Your password has been reset.', title: 'All set');
      await Get.find<AuthController>().signInWithEmail(
        email: email,
        password: password,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Obx(() {
            final busy = reset.isBusy.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: staggered([
                const AuthHeader(
                  title: 'Create New Password',
                  subtitle: Text(
                    'Enter your new password and log in\nto your account',
                  ),
                ),
                const SizedBox(height: 52),
                ShakeX(
                  trigger: _shake,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        label: 'Password',
                        controller: _passwordController,
                        hintText: '************',
                        isPassword: true,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Confirm Password',
                        controller: _confirmController,
                        hintText: '************',
                        isPassword: true,
                        enabled: !busy,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) => Validators.confirmPassword(
                          value,
                          _passwordController.text,
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            child: child,
                          ),
                        ),
                        child: _matches
                            ? const Row(
                                key: ValueKey('match'),
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Color(0xFF1FB57A),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Passwords match',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1FB57A),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(key: ValueKey('none'), height: 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                AuthPrimaryButton(
                  label: 'Reset Password',
                  loading: busy,
                  onPressed: _submit,
                ),
              ], stepMs: 50),
            );
          }),
        ),
      ),
    );
  }
}

class _ResetDoneSheet extends StatelessWidget {
  const _ResetDoneSheet({required this.serverChanged});

  final bool serverChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedCheck(size: 92),
            const SizedBox(height: 18),
            Text(
              serverChanged ? 'Password updated' : 'Almost done',
              style: AuthText.title,
            ),
            const SizedBox(height: 8),
            Text(
              serverChanged
                  ? 'You can now sign in with your new password.'
                  : 'Free-plan demo: open the reset link we emailed you to '
                        'confirm the new password, then sign in.',
              textAlign: TextAlign.center,
              style: AuthText.subtitle,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Back to Sign In',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
