/// Display currencies. Prices are stored in USD; other currencies use demo
/// conversion rates (a live FX feed would need a paid API).
enum AppCurrency {
  usd('USD', r'$', 1, 'US Dollar'),
  eur('EUR', '€', 0.92, 'Euro'),
  gbp('GBP', '£', 0.79, 'British Pound'),
  ils('ILS', '₪', 3.7, 'Israeli Shekel'),
  jod('JOD', 'JD ', 0.709, 'Jordanian Dinar');

  const AppCurrency(this.code, this.symbol, this.rate, this.label);

  final String code;
  final String symbol;
  final double rate;
  final String label;

  static AppCurrency fromCode(String? code) => AppCurrency.values.firstWhere(
    (value) => value.code == code,
    orElse: () => AppCurrency.usd,
  );
}

class Money {
  Money._();

  /// Changed by SettingsController; the app is rebuilt after a change.
  static AppCurrency currency = AppCurrency.usd;

  /// `1499.5` → `$1,499.50` in the selected currency.
  static String format(double usd, {AppCurrency? as}) {
    final target = as ?? currency;
    final value = usd * target.rate;
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }
    return '${negative ? '-' : ''}${target.symbol}$buffer.${parts[1]}';
  }
}
