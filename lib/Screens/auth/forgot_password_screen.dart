import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/password_reset_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/validators.dart';
import '../../repositories/password_reset_repository.dart';
import 'verify_code_screen.dart';
import 'widgets/auth_ui.dart';
import '../../core/utils/navigation.dart';

/// Forgot Password (design page 7).
/// Animations: staggered entrance, floating envelope illustration, shake on an
/// invalid email, button morph.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  // The flow's state is owned by this route and disposed with it.
  final PasswordResetController reset = Get.put(
    PasswordResetController(Get.find<PasswordResetRepository>()),
  );
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);
  int _shake = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _float.dispose();
    Get.delete<PasswordResetController>();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    final sent = await reset.sendCode(_emailController.text);
    if (sent && mounted) {
      Get.to(() => const VerifyCodeScreen(), transition: Transition.cupertino);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: Form(
        key: _formKey,
        child: Obx(() {
          final busy = reset.isBusy.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered([
              const AuthHeader(
                title: 'Forgot Password',
                subtitle: Text('Enter your email to reset password'),
              ),
              const SizedBox(height: 28),
              Center(
                child: AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      -6 * Curves.easeInOut.transform(_float.value),
                    ),
                    child: child,
                  ),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AuthColors.field,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ShakeX(
                trigger: _shake,
                child: AuthTextField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'example@gmail.com',
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  onSubmitted: (_) => _sendCode(),
                ),
              ),
              const SizedBox(height: 32),
              AuthPrimaryButton(
                label: 'Send Code',
                loading: busy,
                onPressed: _sendCode,
              ),
              const SizedBox(height: 20),
              AuthFooterPrompt(
                prompt: 'Remember your password?',
                action: 'Sign In',
                onTap: busy ? null : popPage,
              ),
            ], stepMs: 50),
          );
        }),
      ),
    );
  }
}
