import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/animations/motion.dart';

/// Design tokens for the onboarding and authentication screens, which follow
/// the black-and-white "E-Commerce Mobile App UI Kit" design.
class AuthColors {
  AuthColors._();

  static const Color black = Color(0xFF000000);
  static const Color text = Color(0xFF111111);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color hint = Color(0xFFA3A3A3);
  static const Color field = Color(0xFFF4F4F4);
  static const Color border = Color(0xFFE6E6E6);
  static const Color divider = Color(0xFFE8E8E8);
  static const Color placeholderDot = Color(0xFFE0E0E0);
  static const Color accent = Color(0xFFE13D5C);
  static const Color error = Color(0xFFD32F2F);
}

class AuthText {
  AuthText._();

  static const String fontFamily = 'WorkSans';

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AuthColors.text,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.45,
    color: AuthColors.muted,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AuthColors.text,
  );

  static const TextStyle input = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    color: AuthColors.text,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle link = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AuthColors.text,
  );
}

/// White page with dark status bar icons, the Work Sans font, tap-outside to
/// dismiss the keyboard and an optional back chevron in the top-left corner.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.showBack = false});

  final Widget child;
  final bool showBack;

  /// Distance from the top safe-area edge to the page title.
  static const double titleTop = 72;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(primary: AuthColors.black),
          textTheme: base.textTheme.apply(fontFamily: AuthText.fontFamily),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AuthColors.black,
            selectionColor: Color(0x33000000),
            selectionHandleColor: AuthColors.black,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, titleTop, 16, 24),
                      child: child,
                    ),
                  ),
                  if (showBack)
                    const Positioned(left: 4, top: 10, child: AuthBackButton()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      iconSize: 26,
      color: AuthColors.text,
      icon: const Icon(CupertinoIcons.back),
    );
  }
}

/// Centered page title with a muted subtitle underneath.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: AuthText.title),
        const SizedBox(height: 8),
        DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          style: AuthText.subtitle,
          child: subtitle,
        ),
      ],
    );
  }
}

/// Labelled grey text field. Password fields get the eye toggle.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.isPassword;

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: color == Colors.transparent
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AuthText.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscured,
          obscuringCharacter: '*',
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          keyboardType: widget.isPassword
              ? TextInputType.visiblePassword
              : widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          style: AuthText.input,
          cursorColor: AuthColors.black,
          cursorWidth: 1.5,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AuthText.input.copyWith(color: AuthColors.hint),
            filled: true,
            fillColor: AuthColors.field,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            disabledBorder: _border(Colors.transparent),
            focusedBorder: _border(AuthColors.black),
            errorBorder: _border(AuthColors.error),
            focusedErrorBorder: _border(AuthColors.error, 1.2),
            errorStyle: AuthText.input.copyWith(
              fontSize: 12,
              color: AuthColors.error,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 44,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    color: AuthColors.text,
                    iconSize: 22,
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Full-width black pill button: shrinks on press and morphs its label into
/// a spinner while loading.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: loading ? null : onPressed,
        scale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 52,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AuthColors.black,
            borderRadius: BorderRadius.circular(26),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label, key: ValueKey(label), style: AuthText.button),
          ),
        ),
      ),
    );
  }
}

/// "Or continue with" separator.
class AuthDividerLabel extends StatelessWidget {
  const AuthDividerLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthColors.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(label, style: AuthText.subtitle),
        ),
        const Expanded(child: Divider(color: AuthColors.divider, height: 1)),
      ],
    );
  }
}

enum SocialProvider { google, apple }

/// Outlined square-ish button showing a provider logo.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.loading = false,
  });

  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = switch (provider) {
      SocialProvider.google => 'Continue with Google',
      SocialProvider.apple => 'Continue with Apple',
    };
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: PressableScale(
          onTap: loading ? null : onPressed,
          scale: 0.92,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AuthColors.border),
            ),
            child: InkWell(
              // Taps are handled by PressableScale above.
              onTap: null,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 92,
                height: 54,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AuthColors.black,
                          ),
                        )
                      : switch (provider) {
                          SocialProvider.google => const GoogleLogo(size: 26),
                          SocialProvider.apple => const Icon(
                            Icons.apple,
                            size: 34,
                            color: AuthColors.black,
                          ),
                        },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Question? Action" line at the bottom of the auth screens.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$prompt ', style: AuthText.subtitle),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              action,
              style: AuthText.link.copyWith(
                color: onTap == null ? AuthColors.muted : AuthColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The multicolour Google "G", drawn from the official 48×48 artwork so it
/// stays sharp at any size without an image asset.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final paint = Paint()..isAntiAlias = true;

    final red = Path()
      ..moveTo(24, 9.5)
      ..relativeCubicTo(3.54, 0, 6.71, 1.22, 9.21, 3.6)
      ..relativeLineTo(6.85, -6.85)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..relativeLineTo(7.98, 6.19)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();
    canvas.drawPath(red, paint..color = const Color(0xFFEA4335));

    final blue = Path()
      ..moveTo(46.98, 24.55)
      ..relativeCubicTo(0, -1.57, -0.15, -3.09, -0.38, -4.55)
      ..lineTo(24, 20)
      ..relativeLineTo(0, 9.02)
      ..relativeLineTo(12.94, 0)
      ..relativeCubicTo(-0.58, 2.96, -2.26, 5.48, -4.78, 7.18)
      ..relativeLineTo(7.73, 6)
      ..relativeCubicTo(4.51, -4.18, 7.09, -10.36, 7.09, -17.65)
      ..close();
    canvas.drawPath(blue, paint..color = const Color(0xFF4285F4));

    final yellow = Path()
      ..moveTo(10.53, 28.59)
      ..relativeCubicTo(-0.48, -1.45, -0.76, -2.99, -0.76, -4.59)
      ..cubicTo(9.77, 22, 10.04, 20.86, 10.53, 19.41)
      ..relativeLineTo(-7.98, -6.19)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..relativeCubicTo(0, 3.88, 0.92, 7.54, 2.56, 10.78)
      ..relativeLineTo(7.97, -6.19)
      ..close();
    canvas.drawPath(yellow, paint..color = const Color(0xFFFBBC05));

    final green = Path()
      ..moveTo(24, 48)
      ..relativeCubicTo(6.48, 0, 11.93, -2.13, 15.89, -5.81)
      ..relativeLineTo(-7.73, -6)
      ..relativeCubicTo(-2.15, 1.45, -4.92, 2.3, -8.16, 2.3)
      ..relativeCubicTo(-6.26, 0, -11.57, -4.22, -13.47, -9.91)
      ..relativeLineTo(-7.98, 6.19)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();
    canvas.drawPath(green, paint..color = const Color(0xFF34A853));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
