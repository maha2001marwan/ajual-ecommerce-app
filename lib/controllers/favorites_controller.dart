import 'dart:async';

import 'package:get/get.dart';

import '../core/errors/error_handler.dart';
import '../models/products.dart';
import '../repositories/favorites_repository.dart';
import 'auth_controller.dart';
import 'notifications_controller.dart';

/// Keeps the current user's wishlist ids in sync with Firestore and
/// re-subscribes automatically whenever the signed-in user changes.
class FavoritesController extends GetxController {
  FavoritesController(this._repository, this._authController);

  final FavoritesRepository _repository;
  final AuthController _authController;

  final RxList<String> favoriteIds = <String>[].obs;

  StreamSubscription<List<String>>? _subscription;
  Worker? _userWorker;
  final Set<String> _pending = {};

  String? get _uid => _authController.user.value?.uid;

  int get count => favoriteIds.length;

  @override
  void onInit() {
    super.onInit();
    _listen();
    _userWorker = ever(_authController.user, (_) => _listen());
  }

  void _listen() {
    _subscription?.cancel();
    favoriteIds.clear();
    final uid = _uid;
    if (uid == null) return;
    _subscription = _repository.watchFavoriteIds(uid).listen(
      (value) {
        // Preserve optimistic state for ids with a write in flight.
        final merged = value.where((id) => !_pending.contains(id)).toList()
          ..addAll(favoriteIds.where(_pending.contains));
        favoriteIds.assignAll(merged);
      },
      onError: (Object error) =>
          AppFeedback.error(error, title: 'Wishlist error'),
    );
  }

  bool isFavorite(String productId) => favoriteIds.contains(productId);

  Future<void> toggleFavorite(Product product) async {
    final uid = _uid;
    if (uid == null || _pending.contains(product.id)) return;

    _pending.add(product.id);
    final shouldAdd = !favoriteIds.contains(product.id);

    // Optimistic update for instant UI feedback.
    if (shouldAdd) {
      favoriteIds.insert(0, product.id);
    } else {
      favoriteIds.remove(product.id);
    }

    try {
      await _repository.setFavorite(uid, product.id, shouldAdd);
      if (shouldAdd) {
        unawaited(
          Get.find<NotificationsController>().recordActivity(
            type: 'favorite',
            title: 'Added to wishlist',
            body: '${product.name} was added to your wishlist.',
            productId: product.id,
          ),
        );
      }
    } catch (error) {
      if (shouldAdd) {
        favoriteIds.remove(product.id);
      } else {
        favoriteIds.insert(0, product.id);
      }
      AppFeedback.error(error, title: 'Could not update wishlist');
    } finally {
      _pending.remove(product.id);
    }
  }

  Future<void> remove(Product product) async {
    if (isFavorite(product.id)) await toggleFavorite(product);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
