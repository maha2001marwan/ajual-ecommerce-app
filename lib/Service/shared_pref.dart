import 'package:shared_preferences/shared_preferences.dart';

import '../models/products.dart';

/// Small per-device preferences. User data lives in Firestore; these are
/// conveniences that don't need to sync (recent searches, view mode…).
class StorageServiceShared {
  StorageServiceShared._();

  static final StorageServiceShared instance = StorageServiceShared._();

  final SharedPreferencesAsync prefs = SharedPreferencesAsync();

  static const String _onboardingSeenKey = 'onboardingSeen';
  static const String _recentSearchesKey = 'recentSearches';
  static const String _recentlyViewedKey = 'recentlyViewed';
  static const String _orderSearchesKey = 'orderSearches';
  static const String _currencyKey = 'currency';
  static const String _gridViewKey = 'productGridView';
  static const String _languageKey = 'language';

  Future<bool> hasSeenOnboarding() async =>
      await prefs.getBool(_onboardingSeenKey) ?? false;

  Future<void> setOnboardingSeen() => prefs.setBool(_onboardingSeenKey, true);

  Future<List<String>> recentSearches() async =>
      await prefs.getStringList(_recentSearchesKey) ?? const [];

  Future<void> saveRecentSearches(List<String> values) =>
      prefs.setStringList(_recentSearchesKey, values);

  Future<List<String>> orderSearches() async =>
      await prefs.getStringList(_orderSearchesKey) ?? const [];

  Future<void> saveOrderSearches(List<String> values) =>
      prefs.setStringList(_orderSearchesKey, values);

  /// Product ids, most recent first, scoped per user id.
  Future<List<String>> recentlyViewed(String scope) async =>
      await prefs.getStringList('${_recentlyViewedKey}_$scope') ?? const [];

  Future<void> saveRecentlyViewed(String scope, List<String> ids) =>
      prefs.setStringList('${_recentlyViewedKey}_$scope', ids);

  Future<String?> currency() => prefs.getString(_currencyKey);

  Future<void> saveCurrency(String code) => prefs.setString(_currencyKey, code);

  Future<String?> language() => prefs.getString(_languageKey);

  Future<void> saveLanguage(String code) => prefs.setString(_languageKey, code);

  Future<bool> gridView() async => await prefs.getBool(_gridViewKey) ?? true;

  Future<void> saveGridView(bool value) => prefs.setBool(_gridViewKey, value);

  // --- Legacy helpers kept for compatibility -------------------------------

  Future<void> saveFavoriteIds(List<String> ids) =>
      prefs.setStringList('favoriteIds', ids);

  Future<List<String>> getFavoriteIds() async =>
      await prefs.getStringList('favoriteIds') ?? [];

  Future<void> saveProduct(Product product) =>
      prefs.setString('product_${product.id}', product.toJson());

  Future<Product?> getProduct(String id) async {
    final productJson = await prefs.getString('product_$id');
    return productJson == null ? null : Product.fromJson(productJson);
  }
}
