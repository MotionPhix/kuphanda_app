/// Malawian mobile numbers, typed the way people type them.
///
/// The server normalises too — it has to, because the app is not the only client
/// — but doing it here as well means the sheet can show "+265 991 234 567"
/// before a code is sent, and refuse an obvious landline without a round trip.
/// Both sides must agree, so this mirrors `App\Support\PhoneNumber`.
class PhoneNumber {
  const PhoneNumber._();

  static const String countryCode = '265';

  /// E.164, or null when the string cannot be a mobile number.
  ///
  /// Local shorthand (0991234567, 991234567) is only expanded for Malawi:
  /// guessing a country for a bare number is how a code reaches a stranger.
  static String? normalise(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    }

    late String digits;
    if (cleaned.startsWith('+')) {
      digits = cleaned.substring(1);
    } else if (cleaned.startsWith(countryCode) && cleaned.length == 12) {
      // 265991234567 — already carries the country code.
      digits = cleaned;
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      digits = '$countryCode${cleaned.substring(1)}';
    } else if (cleaned.length >= 10) {
      // Long enough to already carry a country code.
      if (!RegExp(r'^[1-9]\d{9,14}$').hasMatch(cleaned)) return null;
      return '+$cleaned';
    } else {
      digits = '$countryCode$cleaned';
    }

    final e164 = '+$digits';

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(e164)) return null;

    // A Malawian mobile is +265 8x or 9x. A landline cannot receive WhatsApp,
    // so it is refused here rather than failing silently at the provider.
    if (e164.startsWith('+$countryCode') &&
        !RegExp(r'^\+265[89]\d{8}$').hasMatch(e164)) {
      return null;
    }

    return e164;
  }

  /// What the sheet may show back: recognisable to its owner, not harvestable.
  static String mask(String e164) {
    final digits = e164.replaceAll('+', '');
    if (digits.length < 7) return e164;
    return '+${digits.substring(0, 3)} ••• ••• ${digits.substring(digits.length - 3)}';
  }

  /// Groups the national part for display: 991 234 567.
  static String pretty(String e164) {
    final digits = e164.replaceAll('+', '');
    if (digits.startsWith(countryCode) && digits.length == 12) {
      final national = digits.substring(3);
      return '+$countryCode ${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
    }
    return e164;
  }
}
