const crypto = require("node:crypto");
const { getAuth } = require("firebase-admin/auth");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {
  defineInt,
  defineSecret,
  defineString,
} = require("firebase-functions/params");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");

// SMTP settings. The Firebase CLI asks for the string values on the first
// deploy and stores them in functions/.env.<projectId>. The password is a
// Secret Manager secret: `firebase functions:secrets:set SMTP_PASSWORD`.
const smtpHost = defineString("SMTP_HOST", {
  default: "smtp.gmail.com",
  description: "SMTP server used to send password reset codes.",
});
const smtpPort = defineInt("SMTP_PORT", {
  default: 465,
  description: "SMTP port (465 for SSL, 587 for STARTTLS).",
});
const smtpUser = defineString("SMTP_USER", {
  description: "SMTP user name, e.g. the Gmail address that sends the codes.",
});
const smtpPassword = defineSecret("SMTP_PASSWORD");
const mailFrom = defineString("MAIL_FROM", {
  default: "",
  description: 'Optional From header, e.g. "Ajual <no-reply@example.com>".',
});

const CODE_LENGTH = 4;
const CODE_TTL_MS = 10 * 60 * 1000;
const RESET_TOKEN_TTL_MS = 15 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const SEND_WINDOW_MS = 60 * 60 * 1000;
const MAX_SENDS_PER_WINDOW = 5;
const MAX_VERIFY_ATTEMPTS = 5;
const MIN_PASSWORD_LENGTH = 6;
const MAX_PASSWORD_LENGTH = 128;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CODE_PATTERN = new RegExp(`^\\d{${CODE_LENGTH}}$`);

function normalizeEmail(value) {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !EMAIL_PATTERN.test(email)) return null;
  return email;
}

// Reset state lives in a server-only collection keyed by a hash of the email
// so the address itself never appears in a document id.
function resetRef(email) {
  const id = crypto.createHash("sha256").update(email).digest("hex");
  return getFirestore().collection("passwordResets").doc(id);
}

function hashSecret(secret, salt) {
  return crypto.createHash("sha256").update(`${salt}:${secret}`).digest("hex");
}

function secretMatches(expectedHash, secret, salt) {
  if (typeof expectedHash !== "string" || typeof salt !== "string") {
    return false;
  }
  const actual = Buffer.from(hashSecret(secret, salt), "hex");
  const expected = Buffer.from(expectedHash, "hex");
  return (
    actual.length === expected.length &&
    crypto.timingSafeEqual(actual, expected)
  );
}

function millis(timestamp) {
  return timestamp instanceof Timestamp ? timestamp.toMillis() : 0;
}

let transporter;
function mailTransport() {
  if (!transporter) {
    const port = smtpPort.value();
    transporter = nodemailer.createTransport({
      host: smtpHost.value(),
      port,
      secure: port === 465,
      auth: { user: smtpUser.value(), pass: smtpPassword.value() },
    });
  }
  return transporter;
}

function resetEmail(code) {
  const minutes = CODE_TTL_MS / 60000;
  return {
    subject: `${code} is your Ajual password reset code`,
    text:
      `Your Ajual password reset code is ${code}.\n\n` +
      `It expires in ${minutes} minutes. If you didn't request a password ` +
      "reset, you can ignore this email and your password won't change.",
    html: `
      <div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;color:#111111">
        <h1 style="font-size:22px;margin:0 0 8px">Reset your password</h1>
        <p style="color:#6b6b6b;font-size:14px;line-height:20px;margin:0 0 24px">
          Enter this code in the Ajual app to reset your password. It expires in ${minutes} minutes.
        </p>
        <div style="font-size:32px;font-weight:700;letter-spacing:12px;text-align:center;background:#f4f4f4;border-radius:12px;padding:16px 0 16px 12px">
          ${code}
        </div>
        <p style="color:#6b6b6b;font-size:12px;line-height:18px;margin:24px 0 0">
          If you didn't request a password reset, you can ignore this email and your password won't change.
        </p>
      </div>`,
  };
}

exports.requestPasswordResetCode = onCall(
  { secrets: [smtpPassword] },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    if (!email) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }

    // The response is identical whether or not the account exists so the
    // endpoint can't be used to discover registered emails.
    const response = {
      codeLength: CODE_LENGTH,
      expiresInSeconds: CODE_TTL_MS / 1000,
      resendAfterSeconds: RESEND_COOLDOWN_MS / 1000,
    };

    let user;
    try {
      user = await getAuth().getUserByEmail(email);
    } catch (error) {
      if (error.code === "auth/user-not-found") return response;
      throw error;
    }
    if (user.disabled) return response;

    const ref = resetRef(email);
    const code = crypto
      .randomInt(0, 10 ** CODE_LENGTH)
      .toString()
      .padStart(CODE_LENGTH, "0");
    const salt = crypto.randomBytes(16).toString("hex");
    const now = Date.now();

    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const data = snapshot.data() ?? {};

      const waitMs = millis(data.lastSentAt) + RESEND_COOLDOWN_MS - now;
      if (waitMs > 0) {
        const seconds = Math.ceil(waitMs / 1000);
        throw new HttpsError(
          "resource-exhausted",
          `Please wait ${seconds} seconds before requesting a new code.`,
          { reason: "cooldown", retryAfterSeconds: seconds },
        );
      }

      const windowStartedAt = millis(data.windowStartedAt);
      const inWindow = now - windowStartedAt < SEND_WINDOW_MS;
      const sendCount = inWindow ? (data.sendCount ?? 0) : 0;
      if (sendCount >= MAX_SENDS_PER_WINDOW) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many codes requested. Please try again later.",
          {
            reason: "limit",
            retryAfterSeconds: Math.ceil(
              (windowStartedAt + SEND_WINDOW_MS - now) / 1000,
            ),
          },
        );
      }

      transaction.set(ref, {
        uid: user.uid,
        codeHash: hashSecret(code, salt),
        codeSalt: salt,
        codeExpiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
        attempts: 0,
        sendCount: sendCount + 1,
        windowStartedAt: inWindow
          ? data.windowStartedAt
          : Timestamp.fromMillis(now),
        lastSentAt: Timestamp.fromMillis(now),
      });
    });

    try {
      const sender = mailFrom.value() || `Ajual <${smtpUser.value()}>`;
      await mailTransport().sendMail({
        from: sender,
        to: email,
        ...resetEmail(code),
      });
    } catch (error) {
      logger.error("Could not send a password reset email.", {
        uid: user.uid,
        reason: error.message,
      });
      // Undo the cooldown so the user can retry straight away.
      await ref
        .update({
          codeHash: FieldValue.delete(),
          codeSalt: FieldValue.delete(),
          codeExpiresAt: FieldValue.delete(),
          lastSentAt: FieldValue.delete(),
        })
        .catch(() => {});
      throw new HttpsError(
        "unavailable",
        "We couldn't send the email right now. Please try again.",
      );
    }

    return response;
  },
);

exports.verifyPasswordResetCode = onCall(async (request) => {
  const email = normalizeEmail(request.data?.email);
  const code =
    typeof request.data?.code === "string" ? request.data.code.trim() : "";
  if (!email || !CODE_PATTERN.test(code)) {
    throw new HttpsError(
      "invalid-argument",
      `Enter the ${CODE_LENGTH}-digit code from the email.`,
    );
  }

  const ref = resetRef(email);
  const resetToken = crypto.randomBytes(32).toString("base64url");
  const tokenSalt = crypto.randomBytes(16).toString("hex");
  const now = Date.now();

  // Attempts are counted inside a transaction so parallel guesses can't
  // bypass the limit.
  const outcome = await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (!data || typeof data.codeHash !== "string") return "invalid";
    if (millis(data.codeExpiresAt) < now) return "expired";

    const attempts = data.attempts ?? 0;
    if (attempts >= MAX_VERIFY_ATTEMPTS) return "locked";

    if (!secretMatches(data.codeHash, code, data.codeSalt)) {
      transaction.update(ref, { attempts: attempts + 1 });
      return attempts + 1 >= MAX_VERIFY_ATTEMPTS ? "locked" : "invalid";
    }

    // A code can be used once; it is exchanged for a short-lived reset token.
    transaction.update(ref, {
      codeHash: FieldValue.delete(),
      codeSalt: FieldValue.delete(),
      codeExpiresAt: FieldValue.delete(),
      attempts: 0,
      resetTokenHash: hashSecret(resetToken, tokenSalt),
      resetTokenSalt: tokenSalt,
      resetTokenExpiresAt: Timestamp.fromMillis(now + RESET_TOKEN_TTL_MS),
    });
    return "verified";
  });

  switch (outcome) {
    case "verified":
      return { resetToken, expiresInSeconds: RESET_TOKEN_TTL_MS / 1000 };
    case "expired":
      throw new HttpsError(
        "failed-precondition",
        "This code has expired. Request a new one.",
      );
    case "locked":
      throw new HttpsError(
        "failed-precondition",
        "Too many incorrect attempts. Request a new code.",
      );
    default:
      throw new HttpsError(
        "invalid-argument",
        "That code is incorrect. Please try again.",
      );
  }
});

exports.completePasswordReset = onCall(async (request) => {
  const email = normalizeEmail(request.data?.email);
  const { resetToken, newPassword } = request.data ?? {};
  if (
    !email ||
    typeof resetToken !== "string" ||
    resetToken.length < 20 ||
    resetToken.length > 200
  ) {
    throw new HttpsError(
      "invalid-argument",
      "This reset session is invalid. Please request a new code.",
    );
  }
  if (
    typeof newPassword !== "string" ||
    newPassword.length < MIN_PASSWORD_LENGTH ||
    newPassword.length > MAX_PASSWORD_LENGTH
  ) {
    throw new HttpsError(
      "invalid-argument",
      `Password must be ${MIN_PASSWORD_LENGTH} to ${MAX_PASSWORD_LENGTH} characters.`,
    );
  }

  const ref = resetRef(email);
  const data = (await ref.get()).data();
  if (
    !data ||
    !secretMatches(data.resetTokenHash, resetToken, data.resetTokenSalt)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "This reset session is invalid. Please request a new code.",
    );
  }
  if (millis(data.resetTokenExpiresAt) < Date.now()) {
    throw new HttpsError(
      "failed-precondition",
      "This reset session has expired. Please request a new code.",
    );
  }

  try {
    // Changing the password also revokes the account's existing sessions.
    // The code proved ownership of the inbox, so the email counts as verified.
    await getAuth().updateUser(data.uid, {
      password: newPassword,
      emailVerified: true,
    });
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      await ref.delete();
      throw new HttpsError(
        "failed-precondition",
        "This account no longer exists.",
      );
    }
    if (error.code === "auth/invalid-password") {
      throw new HttpsError(
        "invalid-argument",
        "Please choose a stronger password.",
      );
    }
    throw error;
  }

  await ref.delete();
  return { success: true };
});
