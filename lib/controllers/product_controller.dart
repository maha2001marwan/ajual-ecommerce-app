import 'dart:async';

import 'package:get/get.dart';

import '../Service/shared_pref.dart';
import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../data/prodcuts.dart' as seed;
import '../models/products.dart';
import '../models/category.dart';
import '../repositories/product_repository.dart';
import 'auth_controller.dart';

/// Streams the shared catalogue and keeps per-device browsing history
/// (recently viewed, recent searches).
class ProductController extends GetxController {
  ProductController(
    this._repository,
    this._auth, {
    StorageServiceShared? storage,
  }) : _storage = storage ?? StorageServiceShared.instance;

  final ProductRepository _repository;
  final AuthController _auth;
  final StorageServiceShared _storage;

  final RxList<Product> products = <Product>[].obs;
  final RxList<ShopCategory> categories = <ShopCategory>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxList<String> recentlyViewedIds = <String>[].obs;
  final RxList<String> recentSearches = <String>[].obs;

  /// When the current flash sale ends (rolls over every 12 hours).
  final Rx<DateTime> flashSaleEndsAt = DateTime.now().obs;

  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<List<ShopCategory>>? _categorySub;
  StreamSubscription<int>? _versionSub;
  Timer? _catalogFallbackTimer;
  Worker? _userWorker;

  List<Product>? _remoteProducts;
  List<ShopCategory>? _remoteCategories;
  int? _remoteVersion;

  /// Firestore holds an older catalogue than this build (for example the
  /// re-seed was rejected because firestore.rules were not deployed). The
  /// bundled catalogue is shown instead, so names and photos stay current.
  bool get _remoteIsStale => (_remoteVersion ?? 0) < AppConfig.catalogVersion;

  @override
  void onInit() {
    super.onInit();
    _rollFlashSale();
    _subscribe();
    _loadHistory();
    _userWorker = ever(_auth.user, (_) => _loadHistory());
  }

  void _rollFlashSale() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    var end = base.add(const Duration(hours: 12));
    while (!end.isAfter(now.add(const Duration(minutes: 1)))) {
      end = end.add(const Duration(hours: 12));
    }
    flashSaleEndsAt.value = end;
  }

  /// Called by the countdown when it reaches zero.
  void flashSaleEnded() => _rollFlashSale();

  void _subscribe() {
    isLoading.value = true;
    errorMessage.value = '';
    _productSub?.cancel();
    _categorySub?.cancel();
    _versionSub?.cancel();
    _catalogFallbackTimer?.cancel();
    // Firestore normally emits its cache immediately. If it cannot provide an
    // initial snapshot (for example, a cold offline launch), show the bundled
    // catalogue instead of keeping the home screen on skeletons indefinitely.
    _catalogFallbackTimer = Timer(const Duration(seconds: 10), () {
      if (isLoading.value && products.isEmpty) {
        products.assignAll(seed.products);
        isLoading.value = false;
      }
    });
    _versionSub = _repository.watchCatalogVersion().listen(
      (value) {
        _remoteVersion = value;
        _publishCatalog();
      },
      // Unknown version: keep treating Firestore as stale (bundled data).
      onError: (Object _) {},
    );
    _productSub = _repository.watchProducts().listen(
      (value) {
        _catalogFallbackTimer?.cancel();
        _remoteProducts = value;
        _publishCatalog();
        isLoading.value = false;
        errorMessage.value = '';
      },
      onError: (Object error) {
        _catalogFallbackTimer?.cancel();
        errorMessage.value = AppException.from(error).message;
        isLoading.value = false;
      },
    );
    _categorySub = _repository.watchCategories().listen(
      (value) {
        _remoteCategories = value;
        _publishCatalog();
      },
      onError: (Object _) {
        // Fall back to the bundled list so navigation still works.
        if (categories.isEmpty) categories.assignAll(seed.categories);
      },
    );
  }

  /// Shows Firestore's catalogue when it is current, otherwise the bundled
  /// one (also used until the catalogue has been seeded at all).
  void _publishCatalog() {
    final stale = _remoteIsStale;
    final remoteProducts = _remoteProducts;
    if (remoteProducts != null) {
      products.assignAll(
        stale || remoteProducts.isEmpty ? seed.products : remoteProducts,
      );
    }
    final remoteCategories = _remoteCategories;
    if (remoteCategories != null) {
      categories.assignAll(
        stale || remoteCategories.isEmpty ? seed.categories : remoteCategories,
      );
    }
  }

  Future<void> retry() async {
    await guard(_repository.seedIfNeeded, errorTitle: 'Could not load data');
    _subscribe();
  }

  /// Pull-to-refresh: the stream is live, so this only re-subscribes.
  Future<void> refreshCatalog() async {
    _subscribe();
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  // --- Catalogue queries ----------------------------------------------------

  /// A snapshot of the whole catalogue.
  List<Product> get visible => products.toList();

  Product? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> get flashSale {
    final seedOrder = {
      for (var index = 0; index < seed.products.length; index++)
        seed.products[index].id: index,
    };
    return visible.where((product) => product.isFlashSale).toList()
      ..sort((a, b) {
        final order = (seedOrder[a.id] ?? seedOrder.length).compareTo(
          seedOrder[b.id] ?? seedOrder.length,
        );
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
  }

  List<Product> inCategory(String category) =>
      visible.where((product) => product.category == category).toList();

  List<Product> related(Product product, {int limit = 6}) {
    final list =
        visible
            .where((p) => p.id != product.id)
            .where(
              (p) =>
                  p.subcategory == product.subcategory ||
                  p.category == product.category,
            )
            .toList()
          ..sort(
            (a, b) => (b.subcategory == product.subcategory ? 1 : 0).compareTo(
              a.subcategory == product.subcategory ? 1 : 0,
            ),
          );
    return list.take(limit).toList();
  }

  /// Another product often bought with [product] (same category, cheaper).
  Product? boughtTogether(Product product) {
    final candidates = related(product, limit: 10);
    if (candidates.isEmpty) return null;
    return candidates.firstWhere(
      (p) => p.subcategory != product.subcategory && p.inStock,
      orElse: () => candidates.first,
    );
  }

  ShopCategory? categoryByName(String name) {
    for (final category in categories) {
      if (category.name == name) return category;
    }
    return null;
  }

  /// Brands / sellers / colours / sizes present in [source] (for the filter).
  Set<String> brandsIn(Iterable<Product> source) =>
      source.map((p) => p.brand).toSet();
  Set<String> sellersIn(Iterable<Product> source) =>
      source.map((p) => p.seller).toSet();
  Map<String, String> colorsIn(Iterable<Product> source) => {
    for (final p in source)
      for (final option in p.options) option.name: option.hex,
  };
  Set<String> sizesIn(Iterable<Product> source) => {
    for (final p in source) ...p.sizes,
  };

  /// Suggestions while typing: matching product names first, then brands.
  List<String> suggestionsFor(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <String>{};
    for (final product in visible) {
      if (product.name.toLowerCase().contains(q)) {
        results.add(product.name);
      }
    }
    for (final product in visible) {
      if (product.brand.toLowerCase().contains(q)) {
        results.add('$q ${product.subcategory.toLowerCase()}');
      }
    }
    return results.take(8).toList();
  }

  // --- History ----------------------------------------------------------------

  String get _scope => _auth.user.value?.uid ?? 'guest';

  Future<void> _loadHistory() async {
    try {
      recentlyViewedIds.assignAll(await _storage.recentlyViewed(_scope));
      recentSearches.assignAll(await _storage.recentSearches());
    } catch (_) {
      // Preferences are a convenience; ignore failures.
    }
  }

  List<Product> get recentlyViewed =>
      recentlyViewedIds.map(productById).whereType<Product>().toList();

  void markViewed(String productId) {
    recentlyViewedIds
      ..remove(productId)
      ..insert(0, productId);
    if (recentlyViewedIds.length > 20) {
      recentlyViewedIds.removeRange(20, recentlyViewedIds.length);
    }
    unawaited(_storage.saveRecentlyViewed(_scope, recentlyViewedIds.toList()));
  }

  void clearRecentlyViewed() {
    recentlyViewedIds.clear();
    unawaited(_storage.saveRecentlyViewed(_scope, const []));
  }

  void addRecentSearch(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    recentSearches
      ..removeWhere((item) => item.toLowerCase() == value.toLowerCase())
      ..insert(0, value);
    if (recentSearches.length > 8) {
      recentSearches.removeRange(8, recentSearches.length);
    }
    unawaited(_storage.saveRecentSearches(recentSearches.toList()));
  }

  void removeRecentSearch(String query) {
    recentSearches.remove(query);
    unawaited(_storage.saveRecentSearches(recentSearches.toList()));
  }

  void clearRecentSearches() {
    recentSearches.clear();
    unawaited(_storage.saveRecentSearches(const []));
  }

  @override
  void onClose() {
    _catalogFallbackTimer?.cancel();
    _productSub?.cancel();
    _categorySub?.cancel();
    _versionSub?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
