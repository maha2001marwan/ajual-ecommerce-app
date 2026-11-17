import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import 'Screens/auth_gate.dart';
import 'Service/shared_pref.dart';
import 'controllers/address_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/cart_controller.dart';
import 'controllers/favorites_controller.dart';
import 'controllers/notifications_controller.dart';
import 'controllers/onboarding_controller.dart';
import 'controllers/orders_controller.dart';
import 'controllers/payment_controller.dart';
import 'controllers/product_controller.dart';
import 'controllers/review_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/shell_controller.dart';
import 'firebase_options.dart';
import 'repositories/address_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/cart_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/notifications_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/password_reset_repository.dart';
import 'repositories/payment_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/user_repository.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupApp());
}

/// Initializes services after Flutter can already render a useful loading or
/// error screen. Initialization failures used to leave the native splash up.
class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  Object? _error;
  bool _ready = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _configureFirestore();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      _registerDependencies(hasSeenOnboarding: await _hasSeenOnboarding());
      if (mounted) setState(() => _ready = true);
    } catch (error, stackTrace) {
      debugPrint('Application startup failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MyApp();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: _error == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: Colors.white70, size: 44),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not start the app. Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _starting ? null : _start,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Enables offline persistence so reads keep working on weak connections and
/// cached data is served instantly on cold start.
void _configureFirestore() {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (error) {
    // Settings can only be applied before Firestore is first used.
    debugPrint('Firestore settings not applied: $error');
  }
}

Future<bool> _hasSeenOnboarding() async {
  try {
    return await StorageServiceShared.instance.hasSeenOnboarding();
  } catch (_) {
    return false;
  }
}

/// Wires repositories and controllers into the GetX service locator.
void _registerDependencies({required bool hasSeenOnboarding}) {
  // Data layer.
  Get.put<AuthRepository>(AuthRepository(), permanent: true);
  Get.put<UserRepository>(UserRepository(), permanent: true);
  Get.put<ProductRepository>(ProductRepository(), permanent: true);
  Get.put<FavoritesRepository>(FavoritesRepository(), permanent: true);
  Get.put<CartRepository>(CartRepository(), permanent: true);
  Get.put<NotificationsRepository>(NotificationsRepository(), permanent: true);
  Get.put<OrderRepository>(OrderRepository(), permanent: true);
  Get.put<PasswordResetRepository>(PasswordResetRepository(), permanent: true);
  Get.put<AddressRepository>(AddressRepository(), permanent: true);
  Get.put<PaymentRepository>(PaymentRepository(), permanent: true);
  Get.put<ReviewRepository>(ReviewRepository(), permanent: true);

  // State layer.
  Get.put<SettingsController>(SettingsController(), permanent: true);
  Get.put<ShellController>(ShellController(), permanent: true);
  final auth = Get.put<AuthController>(
    AuthController(
      Get.find<AuthRepository>(),
      Get.find<UserRepository>(),
      Get.find<ProductRepository>(),
    ),
    permanent: true,
  );
  Get.put<OnboardingController>(
    OnboardingController(auth, completed: hasSeenOnboarding),
    permanent: true,
  );
  Get.put<NotificationsController>(
    NotificationsController(Get.find<NotificationsRepository>(), auth),
    permanent: true,
  );
  Get.put<OrdersController>(
    OrdersController(Get.find<OrderRepository>(), auth),
    permanent: true,
  );
  Get.lazyPut<ProductController>(
    () => ProductController(Get.find<ProductRepository>(), auth),
    fenix: true,
  );
  Get.lazyPut<FavoritesController>(
    () => FavoritesController(Get.find<FavoritesRepository>(), auth),
    fenix: true,
  );
  Get.lazyPut<CartController>(
    () => CartController(
      Get.find<CartRepository>(),
      Get.find<ProductRepository>(),
      auth,
      Get.find<ProductController>(),
    ),
    fenix: true,
  );
  Get.lazyPut<AddressController>(
    () => AddressController(Get.find<AddressRepository>(), auth),
    fenix: true,
  );
  Get.lazyPut<PaymentController>(
    () => PaymentController(Get.find<PaymentRepository>(), auth),
    fenix: true,
  );
  Get.lazyPut<ReviewController>(
    () => ReviewController(Get.find<ReviewRepository>(), auth),
    fenix: true,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return GetMaterialApp(
          title: 'Ajual',
          debugShowCheckedModeBanner: false,
          theme: Apptheme.lightTheme,
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 320),
          getPages: AppRoutes.pages,
          // Keeps text readable without breaking fixed design layouts.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.25,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }
}
