/// Entry rule for this app: optional; when entered, 10 or 11 ASCII digits,
/// starting with 0. Checks format only, not ownership/existence of the number.
class DebtPhoneValidator {
  static const digitsError = 'Số điện thoại chỉ được chứa chữ số (0–9).';
  static const formatError =
      'Sai định dạng: nhập 10 hoặc 11 chữ số, bắt đầu bằng 0.';

  static String? validate(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return null;
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) return digitsError;
    if (!RegExp(r'^0[0-9]{9,10}$').hasMatch(phone)) return formatError;
    return null;
  }
}
