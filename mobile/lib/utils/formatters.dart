import 'package:intl/intl.dart';

/// Shared currency/date formatting helpers so every screen/widget renders
/// prices and dates the same way. Currency: INR, "₹123.00".
class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  static String currency(num amount) => _currency.format(amount);

  static String dateTime(DateTime date) => _dateTime.format(date.toLocal());

  static String date(DateTime date) => _date.format(date.toLocal());
}
