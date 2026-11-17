# Ajual

Ajual is a Flutter marketplace app backed by Firebase Authentication and
Cloud Firestore.

## Notifications

- Cart and favorites activity is saved to
  `users/{uid}/notifications/{notificationId}` and appears in the in-app
  Notifications screen.
- FCM device tokens are registered under
  `users/{uid}/deviceTokens/{fcmToken}` after notification permission is granted.
- Checkout uses the `placeOrder` callable. It validates the delivery details,
  reads prices from Firestore, and writes the order and its first notification
  atomically. Orders use cash on delivery.
- The `sendOrderUpdate` Cloud Function sends `order_update` notification
  documents to the recipient's registered devices. A trusted backend can
  update status with the `updateOrderStatus` callable (the caller must have the
  Firebase Auth `admin: true` custom claim), or update an order through the
  Admin SDK; status changes create an in-app notification and an FCM push.
  Client Firestore rules deliberately prevent clients from creating orders or
  `order_update` documents.
- Install the function dependencies with `npm install` from `functions/`, then
  deploy the Firestore rules and functions with
  `firebase deploy --project ajual-95ae8 --only firestore:rules,functions`. Cloud Functions
  deployment requires a Firebase project on the Blaze plan.
- Android receives FCM after notification permission is granted. To enable iOS
  push delivery, add the APNs authentication key in Firebase and enable the
  Push Notifications capability for the iOS Runner target.

## Authentication

- First launch shows the onboarding carousel; after "Get Started" (or any
  sign-in) the flag is stored in shared preferences and the app opens on
  Sign In.
- Sign In supports email/password, Google and Apple. Google and Apple use
  Firebase's provider flow (`signInWithProvider`), so no extra Flutter plugin
  is needed. In the Firebase console, enable **Email/Password**, **Google**
  and **Apple** under Authentication → Sign-in method.
- Android (Google/Apple): register the app's SHA-1 and SHA-256 fingerprints
  in Project settings (`cd android && ./gradlew signingReport` prints them),
  then download the updated `google-services.json`.
- iOS (Google/Apple): the Firebase redirect URL scheme (the "Encoded App ID")
  is already in `ios/Runner/Info.plist`; enable the *Sign in with Apple*
  capability for the Runner target. Apple on Android/web also needs a Services
  ID and key configured in the Apple provider settings.

### Password reset with an emailed code

Forgot Password → Verify Code → New Password is backed by three callables in
`functions/passwordReset.js`:

1. `requestPasswordResetCode` emails a 4-digit code (valid 10 minutes). It
   answers the same way for unknown emails, enforces a 60 s resend cooldown
   and at most 5 codes per hour.
2. `verifyPasswordResetCode` allows 5 attempts per code and exchanges a
   correct code for a one-time reset token (valid 15 minutes).
3. `completePasswordReset` sets the new password with the Admin SDK, which
   also signs the account out on other devices. The app then signs in with
   the new password.

Codes and tokens are stored only as salted hashes in `passwordResets/`, which
clients cannot read or write.

Email is sent over SMTP with nodemailer. For Gmail, create an
[app password](https://myaccount.google.com/apppasswords), then:

```sh
firebase functions:secrets:set SMTP_PASSWORD --project ajual-95ae8
firebase deploy --project ajual-95ae8 --only firestore:rules,functions
```

On the first deploy the CLI asks for `SMTP_USER` (the sending address),
`SMTP_HOST` (default `smtp.gmail.com`), `SMTP_PORT` (default `465`) and an
optional `MAIL_FROM`, and saves them to `functions/.env.ajual-95ae8`.
