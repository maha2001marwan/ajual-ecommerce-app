import 'package:get/get.dart';

import '../Service/shared_pref.dart';
import '../core/utils/money.dart';

/// Per-device display settings: currency, language and product view mode.
class SettingsController extends GetxController {
  SettingsController({StorageServiceShared? storage})
    : _storage = storage ?? StorageServiceShared.instance;

  final StorageServiceShared _storage;

  final Rx<AppCurrency> currency = AppCurrency.usd.obs;
  final RxString language = 'en'.obs;
  final RxBool gridView = true.obs;

  static const Map<String, String> languages = {
    'en': 'English',
    'ar': 'العربية',
  };

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await _storage.currency();
      currency.value = AppCurrency.fromCode(code);
      Money.currency = currency.value;
      language.value = await _storage.language() ?? 'en';
      gridView.value = await _storage.gridView();
      if (currency.value != AppCurrency.usd) Get.forceAppUpdate();
    } catch (_) {}
  }

  Future<void> setCurrency(AppCurrency value) async {
    currency.value = value;
    Money.currency = value;
    await Get.forceAppUpdate();
    try {
      await _storage.saveCurrency(value.code);
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    language.value = code;
    try {
      await _storage.saveLanguage(code);
    } catch (_) {}
  }

  void toggleGrid() {
    gridView.toggle();
    _storage.saveGridView(gridView.value).ignore();
  }
}
