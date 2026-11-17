import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/validators.dart';
import 'widgets/auth_ui.dart';
import '../../core/utils/navigation.dart';

enum _SignUpMethod { email, google, apple }

/// "Create An Account" (design page 10): Name, Email, Password.
/// Animations: staggered entrance, live password-strength bar, shake on
/// invalid input, button morph.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthController auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _SignUpMethod? _pending;
  int _shake = 0;
  double _strength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateStrength() {
    final text = _passwordController.text;
    var score = 0.0;
    if (text.length >= 6) score += 0.25;
    if (text.length >= 10) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(text) && RegExp(r'[a-z]').hasMatch(text)) {
      score += 0.25;
    }
    if (RegExp(r'[0-9]').hasMatch(text) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
      score += 0.25;
    }
    if (score != _strength) setState(() => _strength = score);
  }

  Future<void> _submit(_SignUpMethod method) async {
    if (auth.isBusy.value) return;
    if (method == _SignUpMethod.email &&
        !(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _pending = method);
    switch (method) {
      case _SignUpMethod.email:
        await auth.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      case _SignUpMethod.google:
        await auth.signInWithGoogle();
      case _SignUpMethod.apple:
        await auth.signInWithApple();
    }
    if (!mounted) return;
    setState(() => _pending = null);
    // AuthGate reacts to the auth state change; pop back to it.
    if (auth.isAuthenticated) Get.until((route) => route.isFirst);
  }

  Color get _strengthColor {
    if (_strength <= 0.25) return const Color(0xFFE53935);
    if (_strength <= 0.5) return const Color(0xFFFB8C00);
    if (_strength <= 0.75) return const Color(0xFFFDD835);
    return const Color(0xFF43A047);
  }

  String get _strengthLabel {
    if (_passwordController.text.isEmpty) return '';
    if (_strength <= 0.25) return 'Weak';
    if (_strength <= 0.5) return 'Fair';
    if (_strength <= 0.75) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Obx(() {
            final busy = auth.isBusy.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: staggered([
                const AuthHeader(
                  title: 'Create An Account',
                  subtitle: Text(
                    'Enter your details or sign up with your\nsocial account',
                  ),
                ),
                const SizedBox(height: 40),
                ShakeX(
                  trigger: _shake,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        label: 'Name',
                        controller: _nameController,
                        hintText: 'ex. John Smith',
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Email',
                        controller: _emailController,
                        hintText: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Password',
                        controller: _passwordController,
                        hintText: '************',
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: Validators.password,
                        onSubmitted: (_) => _submit(_SignUpMethod.email),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: _strength),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(
                                      value: value,
                                      minHeight: 4,
                                      backgroundColor: AuthColors.field,
                                      color: _strengthColor,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 48,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _strengthLabel,
                                key: ValueKey(_strengthLabel),
                                style: AuthText.subtitle.copyWith(
                                  fontSize: 12,
                                  color: _strengthColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                AuthPrimaryButton(
                  label: 'Sign Up',
                  loading: busy && _pending == _SignUpMethod.email,
                  onPressed: busy ? null : () => _submit(_SignUpMethod.email),
                ),
                const SizedBox(height: 32),
                const AuthDividerLabel(label: 'Or continue with'),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SocialAuthButton(
                      provider: SocialProvider.google,
                      loading: busy && _pending == _SignUpMethod.google,
                      onPressed: busy
                          ? null
                          : () => _submit(_SignUpMethod.google),
                    ),
                    const SizedBox(width: 16),
                    SocialAuthButton(
                      provider: SocialProvider.apple,
                      loading: busy && _pending == _SignUpMethod.apple,
                      onPressed: busy
                          ? null
                          : () => _submit(_SignUpMethod.apple),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                AuthFooterPrompt(
                  prompt: 'Already have an account?',
                  action: 'Sign In',
                  onTap: busy ? null : popPage,
                ),
              ], stepMs: 45),
            );
          }),
        ),
      ),
    );
  }
}
