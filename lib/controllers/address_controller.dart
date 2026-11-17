import 'dart:async';

import 'package:get/get.dart';

import '../core/errors/error_handler.dart';
import '../models/address.dart';
import '../repositories/address_repository.dart';
import 'auth_controller.dart';

class AddressController extends GetxController {
  AddressController(this._repository, this._auth);

  final AddressRepository _repository;
  final AuthController _auth;

  final RxList<Address> addresses = <Address>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;

  StreamSubscription<List<Address>>? _subscription;
  Worker? _userWorker;

  String? get _uid => _auth.user.value?.uid;

  Address? get defaultAddress =>
      addresses.firstWhereOrNull((a) => a.isDefault) ??
      (addresses.isEmpty ? null : addresses.first);

  Address? byId(String? id) =>
      id == null ? null : addresses.firstWhereOrNull((a) => a.id == id);

  @override
  void onInit() {
    super.onInit();
    _listen();
    _userWorker = ever(_auth.user, (_) => _listen());
  }

  void _listen() {
    _subscription?.cancel();
    addresses.clear();
    final uid = _uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    _subscription = _repository.watch(uid).listen(
      (value) {
        addresses.assignAll(value);
        isLoading.value = false;
      },
      onError: (Object error) {
        isLoading.value = false;
        AppFeedback.error(error, title: 'Could not load addresses');
      },
    );
  }

  /// Saves and returns the id, or null on failure. The first address saved
  /// always becomes the default.
  Future<String?> save(Address address) async {
    final uid = _uid;
    if (uid == null || isSaving.value) return null;
    isSaving.value = true;
    try {
      final toSave = addresses.isEmpty ? address.copyWith(isDefault: true) : address;
      final id = await _repository.save(uid, toSave);
      AppFeedback.success('Address saved');
      return id;
    } catch (error) {
      AppFeedback.error(error, title: 'Could not save address');
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> delete(Address address) async {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = addresses.toList();
    addresses.removeWhere((a) => a.id == address.id);
    final ok = await guard(
      () => _repository.delete(uid, address.id),
      errorTitle: 'Could not delete address',
    );
    if (!ok) addresses.assignAll(snapshot);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
