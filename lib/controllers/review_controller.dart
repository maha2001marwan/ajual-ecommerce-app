import 'dart:async';

import 'package:get/get.dart';

import '../core/errors/error_handler.dart';
import '../models/review.dart';
import '../repositories/review_repository.dart';
import 'auth_controller.dart';

class ReviewController extends GetxController {
  ReviewController(this._repository, this._auth);

  final ReviewRepository _repository;
  final AuthController _auth;

  final RxList<Review> myReviews = <Review>[].obs;
  final RxBool isSubmitting = false.obs;

  StreamSubscription<List<Review>>? _subscription;
  Worker? _userWorker;

  String? get uid => _auth.user.value?.uid;

  @override
  void onInit() {
    super.onInit();
    _listen();
    _userWorker = ever(_auth.user, (_) => _listen());
  }

  void _listen() {
    _subscription?.cancel();
    myReviews.clear();
    final id = uid;
    if (id == null) return;
    _subscription = _repository.watchForUser(id).listen(
      myReviews.assignAll,
      onError: (Object _) {},
    );
  }

  Stream<List<Review>> watchProduct(String productId) =>
      _repository.watchForProduct(productId);

  Review? myReviewFor(String productId) =>
      myReviews.firstWhereOrNull((r) => r.productId == productId);

  Future<bool> submit({
    required String productId,
    required String productName,
    required double rating,
    required String name,
    required String body,
    String title = '',
    int photoCount = 0,
  }) async {
    final id = uid;
    if (id == null || isSubmitting.value) return false;
    if (rating < 1) {
      AppFeedback.info('Tap the stars to rate this product.', title: 'Rating needed');
      return false;
    }
    isSubmitting.value = true;
    try {
      await _repository.submit(
        Review(
          id: id,
          productId: productId,
          productName: productName,
          userId: id,
          name: name.trim().isEmpty ? 'Customer' : name.trim(),
          rating: rating,
          title: title.trim(),
          body: body.trim(),
          photoCount: photoCount,
        ),
      );
      AppFeedback.success('Thanks for sharing your review!');
      return true;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not submit review');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> delete(Review review) async {
    final id = uid;
    if (id == null) return;
    await guard(
      () => _repository.delete(id, review.productId),
      errorTitle: 'Could not delete review',
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
