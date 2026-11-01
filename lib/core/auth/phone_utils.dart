import 'package:flutter/services.dart';

/// Нормализация российского номера для API (7XXXXXXXXXX).
String normalizePhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.length == 10) {
    digits = '7$digits';
  }
  return digits;
}

String normalizeOtpCode(String input) => input.replaceAll(RegExp(r'\D'), '');

bool isValidRussianPhone(String input) {
  final digits = normalizePhone(input);
  return digits.length == 11 && digits.startsWith('7');
}

String formatPhoneForDisplay(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+7 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-'
        '${digits.substring(7, 9)}-${digits.substring(9)}';
  }
  return raw;
}

/// Маска ввода: +7 (XXX) XXX-XX-XX
class RussianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.startsWith('7')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    final buffer = StringBuffer('+7');
    if (digits.isNotEmpty) {
      buffer.write(' (');
      final area = digits.length <= 3 ? digits : digits.substring(0, 3);
      buffer.write(area);
      if (digits.length >= 3) {
        buffer.write(') ');
        final mid = digits.length <= 3
            ? ''
            : digits.substring(3, digits.length.clamp(3, 6));
        buffer.write(mid);
        if (digits.length > 6) {
          buffer.write('-');
          final part1 = digits.substring(6, digits.length.clamp(6, 8));
          buffer.write(part1);
          if (digits.length > 8) {
            buffer.write('-');
            buffer.write(digits.substring(8));
          }
        }
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
