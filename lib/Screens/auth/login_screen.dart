import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/validators.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_ui.dart';

enum _SignInMethod { email, google, apple }

/// Sign In (design page 6).
/// Animations: staggered entrance, form shake on invalid input, button
/// press/morph, social buttons press-scale.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _SignInMethod? _pending;
  int _shake = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn(_SignInMethod method) async {
    if (auth.isBusy.value) return;
    if (method == _SignInMethod.email &&
        !(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _pending = method);
    switch (method) {
      case _SignInMethod.email:
        await auth.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      case _SignInMethod.google:
        await auth.signInWithGoogle();
      case _SignInMethod.apple:
        await auth.signInWithApple();
    }
    if (!mounted) return;
    setState(() {
      _pending = null;
      if (!auth.isAuthenticated && method == _SignInMethod.email) _shake++;
    });
  }

  void _openForgotPassword() {
    final email = _emailController.text.trim();
    Get.to(
      () => ForgotPasswordScreen(
        initialEmail: Validators.email(email) == null ? email : null,
      ),
      transition: Transition.cupertino,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Obx(() {
            final busy = auth.isBusy.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: staggered([
                const AuthHeader(
                  title: 'Sign In',
                  subtitle: Text('Welcome back! Please enter your details'),
                ),
                const SizedBox(height: 52),
                ShakeX(
                  trigger: _shake,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        label: 'Email',
                        controller: _emailController,
                        hintText: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),
                      AuthTextField(
                        label: 'Password',
                        controller: _passwordController,
                        hintText: 'Enter your password',
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: Validators.password,
                        onSubmitted: (_) => _signIn(_SignInMethod.email),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: InkWell(
                    onTap: busy ? null : _openForgotPassword,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 2,
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: AuthText.link.copyWith(
                          color: AuthColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AuthPrimaryButton(
                  label: 'Sign In',
                  loading: busy && _pending == _SignInMethod.email,
                  onPressed: busy ? null : () => _signIn(_SignInMethod.email),
                ),
                const SizedBox(height: 32),
                const AuthDividerLabel(label: 'Or continue with'),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SocialAuthButton(
                      provider: SocialProvider.google,
                      loading: busy && _pending == _SignInMethod.google,
                      onPressed: busy
                          ? null
                          : () => _signIn(_SignInMethod.google),
                    ),
                    const SizedBox(width: 16),
                    SocialAuthButton(
                      provider: SocialProvider.apple,
                      loading: busy && _pending == _SignInMethod.apple,
                      onPressed: busy
                          ? null
                          : () => _signIn(_SignInMethod.apple),
                    ),
                  ],
                ),
                const SizedBox(height: 29),
                AuthFooterPrompt(
                  prompt: 'Don’t have an account?',
                  action: 'Sign Up',
                  onTap: busy
                      ? null
                      : () => Get.to(
                          () => const SignupScreen(),
                          transition: Transition.cupertino,
                        ),
                ),
              ], stepMs: 45),
            );
          }),
        ),
      ),
    );
  }
}
