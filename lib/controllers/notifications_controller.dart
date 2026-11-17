import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../core/errors/error_handler.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';
import 'auth_controller.dart';

class NotificationsController extends GetxController {
  NotificationsController(this._repository, this._authController);

  final NotificationsRepository _repository;
  final AuthController _authController;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final RxList<AppNotification> notifications = <AppNotification>[].obs;

  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Worker? _userWorker;
  String? _uid;
  String? _deviceToken;

  int get unreadCount => notifications.where((item) => !item.isRead).length;
  bool get _supportsRemoteMessaging =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void onInit() {
    super.onInit();
    _authController.addBeforeSignOut(_unregisterDevice);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
      onError: (Object error) =>
          AppFeedback.error(error, title: 'Notification error'),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _openInbox(),
      onError: (Object error) =>
          AppFeedback.error(error, title: 'Notification error'),
    );
    _userWorker = ever(_authController.user, (user) {
      unawaited(_bindUser(user?.uid));
    });
    unawaited(_bindUser(_authController.user.value?.uid));
    unawaited(_openInitialMessage());
  }

  /// Deletes this device's token. Runs before sign-out, because by the time
  /// [_bindUser] sees the user change the old account can no longer write.
  Future<void> _unregisterDevice() async {
    final uid = _uid;
    final token = _deviceToken;
    if (uid == null || token == null) return;
    _deviceToken = null;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _repository.removeDeviceToken(uid, token);
  }

  Future<void> _bindUser(String? uid) async {
    if (_uid == uid) return;

    _uid = uid;
    _deviceToken = null;
    await _notificationsSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _notificationsSubscription = null;
    _tokenRefreshSubscription = null;
    notifications.clear();

    if (uid == null) return;

    _notificationsSubscription = _repository
        .watchNotifications(uid)
        .listen(
          notifications.assignAll,
          onError: (Object error) =>
              AppFeedback.error(error, title: 'Could not load notifications'),
        );

    try {
      if (!_supportsRemoteMessaging) return;

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await _messaging.getAPNSToken() == null) {
        return;
      }

      final token = await _messaging.getToken();
      if (token != null && uid == _uid) {
        await _repository.saveDeviceToken(uid, token);
        _deviceToken = token;
      }
      _tokenRefreshSubscription = _repository
          .watchTokenRefresh(_messaging)
          .listen(
            (refreshedToken) {
              unawaited(_saveRefreshedToken(uid, refreshedToken));
            },
            onError: (Object error) => AppFeedback.error(
              error,
              title: 'Could not refresh notifications',
            ),
          );
    } catch (error) {
      AppFeedback.error(error, title: 'Could not enable notifications');
    }
  }

  Future<void> _saveRefreshedToken(String uid, String token) async {
    if (uid != _uid) return;
    try {
      await _repository.saveDeviceToken(uid, token);
      _deviceToken = token;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not refresh notifications');
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if (title == null && body == null) return;

    AppFeedback.info(body ?? '', title: title ?? 'Ajual update');
  }

  Future<void> _openInitialMessage() async {
    if (!_supportsRemoteMessaging) return;
    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openInbox());
      }
    } catch (error) {
      AppFeedback.error(error, title: 'Could not open notification');
    }
  }

  void _openInbox() {
    if (Get.currentRoute != '/notifications') {
      Get.toNamed('/notifications');
    }
  }

  Future<void> recordActivity({
    required String type,
    required String title,
    required String body,
    String? productId,
    String? orderId,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.recordActivity(
        uid: uid,
        type: type,
        title: title,
        body: body,
        productId: productId,
        orderId: orderId,
      );
    } catch (error) {
      AppFeedback.error(error, title: 'Could not save notification');
    }
  }

  Future<void> markRead(AppNotification notification) async {
    final uid = _uid;
    if (uid == null || notification.isRead) return;
    try {
      await _repository.markRead(uid, notification.id);
    } catch (error) {
      AppFeedback.error(error, title: 'Could not update notification');
    }
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unread = notifications.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    try {
      await _repository.markAllRead(uid, unread.map((n) => n.id).toList());
    } catch (error) {
      AppFeedback.error(error, title: 'Could not update notifications');
    }
  }

  Future<void> clearAll() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.deleteAll(
        uid,
        notifications.map((n) => n.id).toList(),
      );
    } catch (error) {
      AppFeedback.error(error, title: 'Could not clear notifications');
    }
  }

  Future<void> deleteNotification(AppNotification notification) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _repository.deleteNotification(uid, notification.id);
    } catch (error) {
      AppFeedback.error(error, title: 'Could not delete notification');
    }
  }

  @override
  void onClose() {
    _notificationsSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
