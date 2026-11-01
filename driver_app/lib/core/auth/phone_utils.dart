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

String formatPhoneForDisplay(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+7 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-'
        '${digits.substring(7, 9)}-${digits.substring(9)}';
  }
  return raw;
}
