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

  /// Always IST, not the viewer's device timezone (.toLocal() would use
  /// whichever zone the customer's/owner's device happens to be set to) —
  /// the store operates in India, so an order placed at, say, 6pm should
  /// read as 6pm IST for everyone looking at it, not shift depending on
  /// who's viewing it from where.
  static String dateTime(DateTime date) => '${_dateTime.format(_toIst(date))} IST';

  static String date(DateTime date) => _date.format(_toIst(date));

  static DateTime _toIst(DateTime date) {
    final utc = date.isUtc ? date : date.toUtc();
    return utc.add(const Duration(hours: 5, minutes: 30));
  }
}
