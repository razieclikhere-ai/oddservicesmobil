import 'package:intl/intl.dart';

class SafeFormat {
  static String date(DateTime date, [String pattern = 'dd MMM yyyy']) {
    try {
      return DateFormat(pattern, 'id_ID').format(date);
    } catch (_) {
      try {
        return DateFormat(pattern).format(date);
      } catch (_) {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }

  static String dateShort(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(date);
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      } catch (_) {
        String doubleDigit(int val) => val < 10 ? '0$val' : '$val';
        return '${doubleDigit(date.day)}/${doubleDigit(date.month)}/${date.year} ${doubleDigit(date.hour)}:${doubleDigit(date.minute)}';
      }
    }
  }

  static String currency(num amount, {String symbol = 'Rp ', int decimalDigits = 0}) {
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: symbol,
        decimalDigits: decimalDigits,
      ).format(amount);
    } catch (_) {
      try {
        return NumberFormat.currency(
          symbol: symbol,
          decimalDigits: decimalDigits,
        ).format(amount);
      } catch (_) {
        return '$symbol$amount';
      }
    }
  }
}
