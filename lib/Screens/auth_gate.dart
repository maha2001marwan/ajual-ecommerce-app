import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/onboarding_controller.dart';
import 'main_shell.dart';
import 'auth/login_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Decides which top-level screen to show based on the persisted auth state:
/// splash while restoring, onboarding on first launch, sign-in screen when
/// signed out, otherwise the main shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();
    final OnboardingController onboarding = Get.find<OnboardingController>();

    return Obx(() {
      final Widget page;
      if (auth.isInitializing.value) {
        page = const _SplashScreen();
      } else if (!auth.isAuthenticated) {
        page = onboarding.completed.value
            ? const LoginScreen()
            : const OnboardingScreen();
      } else {
        page = const MainShell();
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
      );
    });
  }
}

/// Black splash: the logo springs in, the word mark tracks out and a thin
/// progress line sweeps underneath.
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    final word = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: logo,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.black,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              AnimatedBuilder(
                animation: word,
                builder: (context, _) => Opacity(
                  opacity: word.value,
                  child: Text(
                    'AJUAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2 + 8 * word.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 120,
                height: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) => Stack(
                      children: [
                        Container(color: Colors.white12),
                        FractionallySizedBox(
                          widthFactor: 0.35,
                          alignment: Alignment(-1.6 + 3.2 * _sweep.value, 0),
                          child: Container(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
