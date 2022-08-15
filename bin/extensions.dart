import 'package:intl/intl.dart';

int numOfWeeks(int year) {
  final DateTime dec28 = DateTime(year, 12, 28);
  final int dayOfDec28 = int.parse(DateFormat("D").format(dec28));
  return ((dayOfDec28 - dec28.weekday + 10) / 7).floor();
}

extension WeekExtension on DateTime {
  int get week {
    final int dayOfYear = int.parse(DateFormat("D").format(this));
    int woy = ((dayOfYear - weekday + 10) / 7).floor();
    if (woy < 1) {
      woy = numOfWeeks(year - 1);
    } else if (woy > numOfWeeks(year)) {
      woy = 1;
    }
    return woy;
  }
}
