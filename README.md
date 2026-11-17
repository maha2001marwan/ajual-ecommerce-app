# Ajual

Ajual is a cross-platform Flutter e-commerce application backed by Firebase Authentication and Cloud Firestore. It provides a complete marketplace experience, including product discovery, cart and wishlist management, checkout, order tracking, reviews, and in-app notifications.

The project supports two deployment modes:

- **Spark mode (default):** runs on the Firebase free plan with client-side ordering, native Firebase password reset emails, and clearly labeled demo behavior for features that require a paid plan.
- **Blaze mode:** enables Cloud Functions for server-validated orders, emailed one-time reset codes, and FCM order updates.

## Features

- Email/password, Google, and Apple sign-in with an onboarding flow
- Product catalog, categories, search, filtering, and product details
- Cart and wishlist with variant-aware items, optimistic updates, and rollback on failure
- Checkout with delivery addresses, coupons, saved payment methods, and cash on delivery
- Order history, order details, search, and status tracking
- Reviews, recently viewed products, help center, and profile management
- In-app notifications with optional FCM push delivery
- Offline Firestore persistence for resilient reads
- Motion and accessibility support, including system reduce-motion and text-scale limits

## Architecture

```text
lib/
├── Screens/          UI screens and reusable screen widgets
├── controllers/      GetX controllers and application state
├── repositories/     Firebase and local data access
├── models/           Domain models
├── core/             Configuration, constants, utilities, and animations
├── theme/            Colors, typography, and sizing
├── Service/          Shared preferences and Hive storage
├── routes/           Named routes
└── main.dart         App bootstrap and dependency registration

functions/
├── index.js          Order, notification, and FCM Cloud Functions
└── passwordReset.js  Password-reset Cloud Functions
```

The UI communicates with GetX controllers, which delegate persistence to repositories. Repositories use Firebase Auth, Cloud Firestore, Cloud Functions, and local storage. Startup wiring is centralized in `lib/main.dart`.

## Prerequisites

- Dart SDK 3.11.5 or later with a compatible Flutter SDK
- Firebase CLI
- Node.js 22 for Cloud Functions
- Android Studio / Xcode, as needed for the target platform

## Getting started

```sh
flutter pub get
flutter analyze
flutter run
```

The repository is preconfigured for the Firebase project `ajual-95ae8`. When using a different project, update `lib/firebase_options.dart`, `android/app/google-services.json`, the iOS Firebase configuration, and every `--project` argument in the commands below.

## Firebase configuration

Enable the following services in the Firebase console:

| Service | Required setup |
| --- | --- |
| Authentication | Enable **Email/Password**, **Google**, and **Apple** under *Sign-in method*. |
| Firestore | Create the database in production mode and deploy `firestore.rules`. |
| Cloud Messaging | FCM works on Android after notification permission is granted. iOS requires an APNs authentication key and the Push Notifications capability. |
| Authorized domains | Add your domain when deploying the web app. |

For Android Google/Apple sign-in, register the app's SHA-1 and SHA-256 fingerprints, then download the updated configuration file:

```sh
cd android && ./gradlew signingReport
```

For iOS, confirm that the Firebase redirect URL scheme is present in `ios/Runner/Info.plist` and enable the *Sign in with Apple* capability for the Runner target. Apple sign-in on Android or web also requires a Services ID and key in the Apple provider settings.

Deploy the Firestore rules:

```sh
firebase deploy --project ajual-95ae8 --only firestore:rules
```

The catalog is seeded on first sign-in. If you change the bundled catalog, increment `catalogVersion` in `lib/core/config/app_config.dart` and the matching value in `catalogUnlocked()` in `firestore.rules` before deploying; otherwise, existing projects keep the previous catalog.

## Runtime configuration

Build-time switches are defined in `lib/core/config/app_config.dart`:

```dart
static const bool useCloudFunctions = false;
static const bool simulateOrderProgress = true;
```

### Spark mode

With `useCloudFunctions = false`:

- Orders are validated and written from the client in a single atomic Firestore batch.
- Password reset uses Firebase's native reset email; the four-digit code screens are in demo mode.
- Card and PayPal payments are simulated; cash on delivery is fully supported.
- Order status advances locally every three minutes.
- Avatars and review images are not uploaded to Cloud Storage.

### Blaze mode

To enable the server-backed implementation:

1. Upgrade the Firebase project to the Blaze plan.
2. Set `useCloudFunctions = true` and `simulateOrderProgress = false` in `lib/core/config/app_config.dart`.
3. Install the function dependencies:

   ```sh
   npm install --prefix functions
   ```

4. Configure SMTP settings. For Gmail, create an [app password](https://myaccount.google.com/apppasswords), then set the password secret:

   ```sh
   firebase functions:secrets:set SMTP_PASSWORD --project ajual-95ae8
   ```

   The Firebase CLI prompts for `SMTP_USER`, `SMTP_HOST` (default `smtp.gmail.com`), `SMTP_PORT` (default `465`), and optional `MAIL_FROM` on first deploy.

5. Deploy the rules and functions:

   ```sh
   firebase deploy --project ajual-95ae8 --only firestore:rules,functions
   ```

## Cloud Functions

`functions/index.js` exposes:

- `placeOrder` — validates delivery details, reads prices from Firestore, and writes the order and first notification atomically.
- `updateOrderStatus` — allows administrators with the `admin: true` Firebase Auth custom claim to advance orders through valid status transitions.
- `notifyOrderStatusChanged` — creates an in-app notification when an order status changes.
- `sendOrderUpdate` — sends `order_update` FCM pushes to registered devices and removes stale tokens.

`functions/passwordReset.js` exposes:

- `requestPasswordResetCode` — emails a four-digit code valid for 10 minutes, with a 60-second resend cooldown and a limit of five codes per hour.
- `verifyPasswordResetCode` — allows five attempts and exchanges a correct code for a one-time token valid for 15 minutes.
- `completePasswordReset` — updates the password with the Admin SDK, signing the user out on other devices.

Reset codes and tokens are stored only as salted hashes in the server-only `passwordResets/` collection. Firestore rules intentionally prevent clients from creating orders, `order_update` notifications, or reset records.

## Verification

```sh
flutter analyze
flutter test
npm --prefix functions run lint
```

## Known limitations

- Arabic UI text is not translated yet; the Arabic option in settings is marked as coming soon.
- Push notifications on iOS require an Apple Developer account and APNs configuration.
- Product image sources and attribution are documented in `assets/images/CREDITS.md`.
- Server-side price validation requires Blaze mode; client-side totals in Spark mode are suitable for demos, not production.
