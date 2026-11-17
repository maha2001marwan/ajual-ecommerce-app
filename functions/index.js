const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

Object.assign(exports, require("./passwordReset"));
const orderStatuses = {
  pending: "Pending",
  confirmed: "Confirmed",
  shipped: "On the way",
  delivered: "Delivered",
  cancelled: "Cancelled",
};

exports.placeOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before placing an order.");
  }

  const { items, customerName, phoneNumber, deliveryAddress } =
    request.data ?? {};
  if (
    !Array.isArray(items) ||
    items.length === 0 ||
    items.length > 50 ||
    typeof customerName !== "string" ||
    customerName.trim().length < 2 ||
    customerName.trim().length > 100 ||
    typeof phoneNumber !== "string" ||
    !/^\+[1-9]\d{7,14}$/.test(phoneNumber.trim()) ||
    typeof deliveryAddress !== "string" ||
    deliveryAddress.trim().length < 8 ||
    deliveryAddress.trim().length > 500
  ) {
    throw new HttpsError("invalid-argument", "Check the delivery details.");
  }

  const quantities = new Map();
  for (const item of items) {
    if (
      !item ||
      typeof item.productId !== "string" ||
      item.productId.length === 0 ||
      item.productId.length > 150 ||
      !Number.isInteger(item.quantity) ||
      item.quantity < 1 ||
      item.quantity > 99 ||
      quantities.has(item.productId)
    ) {
      throw new HttpsError("invalid-argument", "The cart contains invalid items.");
    }
    quantities.set(item.productId, item.quantity);
  }

  const userId = request.auth.uid;
  const userRef = db.collection("users").doc(userId);
  const orderRef = userRef.collection("orders").doc();
  await db.runTransaction(async (transaction) => {
    const products = [];
    for (const [productId, quantity] of quantities) {
      const productRef = db.collection("products").doc(productId);
      const productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw new HttpsError("failed-precondition", "A product is no longer available.");
      }

      const product = productSnapshot.data();
      if (
        product.inStock !== true ||
        typeof product.name !== "string" ||
        typeof product.price !== "number" ||
        !Number.isFinite(product.price) ||
        product.price < 0
      ) {
        throw new HttpsError("failed-precondition", "A product is out of stock.");
      }
      products.push({
        productId,
        name: product.name,
        unitPrice: product.price,
        quantity,
      });
    }

    const rawTotal = products.reduce(
      (sum, item) => sum + item.unitPrice * item.quantity,
      0,
    );
    const total = Math.round((rawTotal + Number.EPSILON) * 100) / 100;
    const createdAt = FieldValue.serverTimestamp();

    transaction.create(orderRef, {
      customerName: customerName.trim(),
      phoneNumber: phoneNumber.trim(),
      deliveryAddress: deliveryAddress.trim(),
      items: products,
      total,
      currency: "USD",
      paymentMethod: "cash_on_delivery",
      status: "pending",
      createdAt,
      updatedAt: createdAt,
    });
    transaction.create(userRef.collection("notifications").doc(), {
      type: "order_update",
      orderId: orderRef.id,
      title: "Order received",
      body: `Your order #${orderRef.id.slice(0, 8)} is pending confirmation.`,
      createdAt,
      read: false,
    });
  });

  return { orderId: orderRef.id };
});

exports.updateOrderStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to update an order.");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }

  const { userId, orderId, status } = request.data ?? {};
  if (
    typeof userId !== "string" ||
    typeof orderId !== "string" ||
    !Object.hasOwn(orderStatuses, status)
  ) {
    throw new HttpsError("invalid-argument", "The order update is invalid.");
  }

  const orderRef = db
    .collection("users")
    .doc(userId)
    .collection("orders")
    .doc(orderId);
  await db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "The order could not be found.");
    }

    const currentStatus = orderSnapshot.data().status;
    const transitions = {
      pending: ["confirmed", "cancelled"],
      confirmed: ["shipped", "cancelled"],
      shipped: ["delivered"],
      delivered: [],
      cancelled: [],
    };
    if (currentStatus === status) return;
    if (!transitions[currentStatus]?.includes(status)) {
      throw new HttpsError(
        "failed-precondition",
        "This order status change is not allowed.",
      );
    }

    transaction.update(orderRef, {
      status,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

exports.notifyOrderStatusChanged = onDocumentUpdated(
  "users/{userId}/orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const statusName = orderStatuses[after.status];
    if (!statusName) {
      logger.error("Order has an unknown status.", {
        orderId: event.params.orderId,
      });
      return;
    }

    await db
      .collection("users")
      .doc(event.params.userId)
      .collection("notifications")
      .add({
        type: "order_update",
        orderId: event.params.orderId,
        title: "Order update",
        body: `Your order #${event.params.orderId.slice(0, 8)} is now ${statusName.toLowerCase()}.`,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
  },
);

exports.sendOrderUpdate = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const notification = event.data?.data();
    if (!notification || notification.type !== "order_update") return;

    const { userId, notificationId } = event.params;
    const tokenSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("deviceTokens")
      .get();

    const tokens = tokenSnapshot.docs.map((document) => document.id);
    if (tokens.length === 0) {
      logger.info("Order update has no registered devices.", { userId });
      return;
    }

    const title =
      typeof notification.title === "string"
        ? notification.title.slice(0, 120)
        : "Order update";
    const body =
      typeof notification.body === "string"
        ? notification.body.slice(0, 500)
        : "Your order status has changed.";
    const messaging = getMessaging();

    for (let offset = 0; offset < tokens.length; offset += 500) {
      const batch = tokens.slice(offset, offset + 500);
      const result = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data: {
          type: "order_update",
          notificationId,
        },
        android: { priority: "high" },
      });

      const staleTokens = [];
      result.responses.forEach((response, index) => {
        const code = response.error?.code;
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          staleTokens.push(batch[index]);
        } else if (!response.success) {
          logger.error("Could not deliver an order update.", {
            userId,
            code,
          });
        }
      });

      await Promise.all(
        staleTokens.map((token) =>
          db
            .collection("users")
            .doc(userId)
            .collection("deviceTokens")
            .doc(token)
            .delete(),
        ),
      );
    }
  },
);
