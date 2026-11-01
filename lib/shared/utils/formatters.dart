import 'package:intl/intl.dart';

final _priceFormat = NumberFormat('#,##0', 'ru_RU');
final _dateFormat = DateFormat('d MMMM yyyy, HH:mm', 'ru_RU');

String formatPrice(double price) => '≈ ${_priceFormat.format(price.round())} ₽';

String formatPriceExact(double price) =>
    '${_priceFormat.format(price.round())} ₽';

String formatDateTime(DateTime date) => _dateFormat.format(date);

String formatRate(double rate) => '${rate.toStringAsFixed(0)} ₽/км';
