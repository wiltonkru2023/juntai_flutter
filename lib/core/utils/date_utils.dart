import 'package:intl/intl.dart';

abstract final class JuntaiDateUtils {
  static String shortDate(DateTime date) => DateFormat('dd/MM').format(date);
  static String time(DateTime date) => DateFormat('HH:mm').format(date);
}
