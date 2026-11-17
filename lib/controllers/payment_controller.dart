import 'dart:async';

import 'package:get/get.dart';

import '../core/errors/error_handler.dart';
import '../models/payment_card.dart';
import '../repositories/payment_repository.dart';
import 'auth_controller.dart';

class PaymentController extends GetxController {
  PaymentController(this._repository, this._auth);

  final PaymentRepository _repository;
  final AuthController _auth;

  final RxList<PaymentCard> cards = <PaymentCard>[].obs;
  final RxBool isSaving = false.obs;

  StreamSubscription<List<PaymentCard>>? _subscription;
  Worker? _userWorker;

  String? get _uid => _auth.user.value?.uid;

  PaymentRepository get repository => _repository;

  @override
  void onInit() {
    super.onInit();
    _listen();
    _userWorker = ever(_auth.user, (_) => _listen());
  }

  void _listen() {
    _subscription?.cancel();
    cards.clear();
    final uid = _uid;
    if (uid == null) return;
    _subscription = _repository.watch(uid).listen(
      cards.assignAll,
      onError: (Object error) =>
          AppFeedback.error(error, title: 'Could not load cards'),
    );
  }

  /// Saves only brand / last 4 / holder / expiry. Returns the new card.
  Future<PaymentCard?> addCard({
    required String number,
    required String expiry,
    required String holder,
    required String billingAddress,
    required String postalCode,
  }) async {
    final uid = _uid;
    if (uid == null || isSaving.value) return null;
    isSaving.value = true;
    try {
      final digits = number.replaceAll(RegExp(r'\D'), '');
      final card = PaymentCard(
        id: '',
        brand: CardBrand.detect(digits),
        last4: digits.substring(digits.length - 4),
        holder: holder.trim(),
        expiry: expiry,
        billingAddress: billingAddress.trim(),
        postalCode: postalCode.trim(),
        isDefault: cards.isEmpty,
      );
      final id = await _repository.add(uid, card);
      AppFeedback.success('Card ${card.masked} added');
      return PaymentCard(
        id: id,
        brand: card.brand,
        last4: card.last4,
        holder: card.holder,
        expiry: card.expiry,
        billingAddress: card.billingAddress,
        postalCode: card.postalCode,
        isDefault: card.isDefault,
      );
    } catch (error) {
      AppFeedback.error(error, title: 'Could not add card');
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> delete(PaymentCard card) async {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = cards.toList();
    cards.removeWhere((c) => c.id == card.id);
    final ok = await guard(
      () => _repository.delete(uid, card.id),
      errorTitle: 'Could not remove card',
    );
    if (!ok) cards.assignAll(snapshot);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
