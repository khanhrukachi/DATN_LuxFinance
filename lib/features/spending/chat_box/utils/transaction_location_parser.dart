/// Extract location spans while preserving the original Vietnamese spelling.
/// [folded] must be lower-case/accent-folded without changing string offsets.
class TransactionLocationParser {
  static final RegExp _start = RegExp(
      r'(?<![a-z0-9])(?:o|tai|at|dia diem\s*:|location\s*:)\s+');
  static final RegExp _end = RegExp(
      r';|,\s*(?=(?:het|ton|gia|paid|cost|ghi chu|note)\b)|\s+(?:(?:het|ton|gia|cost|paid|spent|for|of|thanh toan)\s+\d|(?:luc|vao luc|at)\s+\d|(?:hom nay|hom qua|today|yesterday)\b|(?:ghi chu|note)\s*:|\d[\d.,]*\s*(?:k|tr|trieu|nghin|ngan|dong|vnd|d)\b)');

  // Unaccented product nouns that resemble unaccented location prepositions.
  // With an explicit accented "ở"/"tại", these exclusions are unnecessary.
  static final RegExp _productPrefix = RegExp(
    r'^(?:tai (?:nghe|lieu|khoan|san|xe|che|trong)|'
    r'o (?:cam|dien|khoa|cung|dia|usb|to|banh|ga|chuot))\b',
  );

  /// Returns [markerStart, contentStart, contentEnd], or null.
  static List<int>? findSpan(String original, String folded) {
    if (original.length != folded.length) return null;
    for (final marker in _start.allMatches(folded)) {
      final matched = original.substring(marker.start, marker.end).trim().toLowerCase();
      final foldedMarker = folded.substring(marker.start, marker.end).trim();
      if (foldedMarker == 'o' || foldedMarker == 'tai') {
        // Distinguish ổ/ô/ố/ổ... from ở, and tai/tải/tái/tài from tại.
        final hasAccents = RegExp(r'[à-ỹđ]').hasMatch(matched);
        if (hasAccents && matched != 'ở' && matched != 'tại') continue;
        if (!hasAccents && _productPrefix.hasMatch(folded.substring(marker.start))) continue;
      }
      final tail = folded.substring(marker.end);
      // "at 7:30" is a time, not a place.
      if (RegExp(r'^\d{1,2}\s*(?::|h|am\b|pm\b)').hasMatch(tail)) continue;
      final stop = _end.firstMatch(tail);
      final end = marker.end + (stop?.start ?? tail.length);
      if (end > marker.end) return [marker.start, marker.end, end];
    }
    return null;
  }
}
