/// Build-time switches that decide which Firebase features are used.
///
/// The app is configured for the free **Spark** plan by default:
/// * Orders are written from the client in one atomic batch (no callable).
/// * Password reset sends Firebase's own reset email; the 4-digit code screens
///   run in demo mode because emailing custom codes needs Cloud Functions.
/// * Card / PayPal payments are simulated (no payment gateway on Spark).
/// * Avatars and review photos are not uploaded (Cloud Storage needs Blaze for
///   new projects since Oct 2024).
///
/// Set [useCloudFunctions] to `true` after upgrading to **Blaze** and deploying
/// the `functions/` folder to switch orders and password reset to the server.
class AppConfig {
  AppConfig._();

  static const bool useCloudFunctions = false;

  /// On Spark nobody updates order status from a backend, so the app advances
  /// demo orders through Confirmed → Shipped → Delivered by elapsed time.
  static const bool simulateOrderProgress = true;

  /// Minutes between simulated status steps.
  static const int simulatedStepMinutes = 3;

  /// Bump when [seed catalog] changes so existing projects get the new data.
  /// Must match the number in `catalogUnlocked()` in firestore.rules, or the
  /// rules reject the re-seed and the old catalogue stays in Firestore.
  static const int catalogVersion = 7;

  static const double freeShippingThreshold = 1000;
  static const double standardShippingFee = 10;
  static const double expressShippingFee = 19;

  static const String supportEmail = 'support@ajual.app';
  static const String supportPhone = '+970 59 000 0000';
  static const String shareBaseUrl = 'https://ajual.app/p/';
}
