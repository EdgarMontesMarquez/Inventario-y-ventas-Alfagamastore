import 'package:intl/intl.dart';

/// Formateador universal de moneda para Alfa Gama Store ERP.
/// Garantiza que el signo '$' SIEMPRE esté ubicado por delante del número.
class CurrencyUtils {
  CurrencyUtils._();

  static final _formatter = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
    customPattern: '\$#,##0',
  );

  static String format(num amount) {
    return _formatter.format(amount);
  }
}
