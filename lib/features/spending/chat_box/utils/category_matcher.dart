import 'package:personal_financial_management/core/constants/list.dart';
import 'offline_category_vocabulary.dart';
import 'category_keyword_rules.dart';
import 'category_keyword_suffixes.dart';
import 'category_semantics.dart';
import 'transaction_action_keywords.dart';

class CategoryMatch {
  final int type;
  final String key;
  final double confidence;

  const CategoryMatch(this.type, this.key, this.confidence);
}

/// Nhận diện danh mục từ cách nói tự nhiên của người dùng.
///
/// Từ khóa được chuẩn hóa bỏ dấu trước khi so khớp, vì vậy các câu như
/// "đi ăn phở", "di an pho" và "pho ga" đều có thể về danh mục ăn uống.
class _CategoryEvidence {
  final int start, end;
  final String key;
  final double score;
  const _CategoryEvidence(this.start, this.end, this.key, this.score);
}

class CategoryAnalysis {
  final List<CategoryMatch> matches;
  final List<String> ambiguousTerms;
  final bool canClarifySingleTerm;
  const CategoryAnalysis(this.matches, this.ambiguousTerms, this.canClarifySingleTerm);
}

class _CategoryTrieNode {
  final Map<String, _CategoryTrieNode> children = {};
  final Set<String> keys = {};
  final Map<String, Set<String>> spellings = {};
  final Map<String, List<List<String>>> suffixes = {};
}

class CategoryMatcher {
  static const Map<String, List<String>> _aliases = {};

  // Từ vựng bổ sung được biên soạn theo sản phẩm và mục đích sử dụng.
  // Không sinh tích Descartes tên hàng × thương hiệu.
  static const Map<String, List<String>> _expanded = {};

  // No fuzzy substring guessing and no category determined by a brand alone.
  static final _CategoryTrieNode _root = _buildTrie();
  static _CategoryTrieNode _buildTrie() {
    final root = _CategoryTrieNode();
    for (final key in {..._aliases.keys, ..._expanded.keys, ...offlineCategoryVocabulary.keys, ...categoryKeywordRules.keys}) {
      for (final alias in {...?_aliases[key], ...?_expanded[key],
          ...?offlineCategoryVocabulary[key], ...?categoryKeywordRules[key], key}) {
        final phrase = _normalize(alias);
        if (phrase.isEmpty) continue;
        if (key != 'personal_belongings' &&
            {'khau trang', 'khau trang y te'}.contains(phrase)) continue;
        if ({'k', 'be', 'in', 'an', 'di', 'tra', 'dong', 'car', 'xe may',
          'benh vien', 'pharmacy', 'hospital', 'bac si'}.contains(phrase)) continue;
        var node = root;
        for (final token in phrase.split(' ')) {
          node = node.children.putIfAbsent(token, () => _CategoryTrieNode());
        }
        node.keys.add(key);
        node.spellings.putIfAbsent(key, () => <String>{}).add(alias.toLowerCase());
      }
    }
    for (final group in categoryKeywordSuffixGroups) {
      for (final head in group.heads) {
        var node = root;
        for (final token in _normalize(head).split(' ')) {
          node = node.children.putIfAbsent(token, () => _CategoryTrieNode());
        }
        node.suffixes.putIfAbsent(group.category, () => <List<String>>[])
            .addAll(group.suffixes.map((s) => _normalize(s).split(' ')));
      }
    }
    return root;
  }

  static CategoryAnalysis analyze(String input) {
    final normalized = _normalize(input);
    final hits = <String, double>{};
    final evidence = <_CategoryEvidence>[];
    final tokens = RegExp(r'[^a-z0-9]+|[a-z0-9]+')
        .allMatches(normalized).where((m) => RegExp(r'^[a-z0-9]+$').hasMatch(m.group(0)!)).toList();
    final originalWords = RegExp(r'[A-Za-zÀ-ỹĐđ0-9]+').allMatches(input).toList();
    final available = <String, int>{};
    for (var i = 0; i < listType.length; i++) {
      final entry = listType[i];
      final key = entry['title'];
      if (key != null && entry['isParent'] != 'true') available.putIfAbsent(key, () => i);
    }
    for (var start = 0; start < tokens.length; start++) {
      var node = _root;
      for (var end = start; end < tokens.length; end++) {
        // Only whitespace may join words in a phrase. Never bridge other symbols.
        if (end > start && normalized.substring(tokens[end-1].end, tokens[end].start).trim().isNotEmpty) break;
        final child = node.children[tokens[end].group(0)!];
        if (child == null) break;
        node = child;
        final score = (0.68 + (end-start+1)*0.055).clamp(0.0, 0.97).toDouble();
        for (final key in {...node.keys, ...node.suffixes.keys}) {
          if (available.containsKey(key)) {
            // Preserve accented single-word meaning: tôi != tỏi, chợ != chó.
            if (start == end && originalWords.length == tokens.length) {
              final original = originalWords[start].group(0)!.toLowerCase();
              final forms = node.spellings[key] ?? const <String>{};
              if (RegExp(r'[à-ỹđ]').hasMatch(original) &&
                  !forms.contains(original) &&
                  forms.every((f) => RegExp(r'[à-ỹđ]').hasMatch(f))) continue;
            }
            if (node.keys.contains(key)) {
              evidence.add(_CategoryEvidence(tokens[start].start, tokens[end].end, key, score));
            }
            for (final suffix in node.suffixes[key] ?? const <List<String>>[]) {
              if (end + suffix.length >= tokens.length) continue;
              var matches = true;
              for (var offset = 0; offset < suffix.length; offset++) {
                if (tokens[end + 1 + offset].group(0) != suffix[offset]) {
                  matches = false;
                  break;
                }
              }
              if (matches) evidence.add(_CategoryEvidence(tokens[start].start,
                  tokens[end + suffix.length].end, key, 0.97));
            }
          }
        }
      }
    }
    // Shared action spans must not become category evidence (e.g. 'cho' in 'chi cho').
    final actionSpans = <RegExpMatch>[
      ...TransactionActionKeywords.purchasePattern.allMatches(normalized),
      ...TransactionActionKeywords.narrativePrefixPattern.allMatches(normalized),
      ...TransactionActionKeywords.incomeActionPattern.allMatches(normalized),
      ...TransactionActionKeywords.neutralPattern.allMatches(normalized),
    ];
    evidence.removeWhere((e) => actionSpans.any((a) => e.start >= a.start && e.end <= a.end));
    // Specific ownership/purpose phrases override generic food/health tokens.
    final policies = <String, String>{
      r'\b(?:thuoc|kham|xet nghiem) (?:(?!(?:va|kem|voi)\b)[a-z0-9]+ ){0,5}cho (?:cho|meo|chim|tho|hamster)\b': 'pet',
      r'\bson (?:duong(?: moi)?|chong nang(?: moi)?|kem|li|bong|tint|thoi|nuoc|moi)\b': 'beautify',
      r'\bthe (?:dien thoai|cao dien thoai)\b': 'telephone_fee',
      r'\b(an|eat|ate)\s+(muc|ca|ga|kem|squid|fish|chicken|ice cream)\b': 'eating',
      r'\b(uong|drink|drank)\s+(sua|nuoc|milk|water)\b': 'eating',
      r'\b(khau trang(?: y te)?|op lung(?: dien thoai)?|medical mask|surgical mask|phone case|phone cover)\b': 'personal_belongings',
      r'\b(thuc an cho (cho|meo)|hat cho (cho|meo)|kham thu y|tiem phong cho (cho|meo)|cat food|dog food|vet bill)\b': 'pet',
      r'\b(nhan li xi|nhan hoan tien|duoc hoan tien|refund received|sold my (phone|laptop))\b': 'other_income',
      r'\b(qua sinh nhat|qua cuoi|mung cuoi|birthday gift|wedding gift)\b': 'gifts_donations',
      r'\b(bep gas|bep tu|noi com dien|may pha ca phe|cooking pot|rice cooker)\b': 'housewares',
      r'\b(thay nhot|rua xe|oil change|car wash)\b': 'vehicle_maintenance',
      r'\b(nap tien dien thoai|cuoc dien thoai|phone bill|mobile top up)\b': 'telephone_fee',
    };
    for (final rule in policies.entries) {
      for (final occurrence in RegExp(rule.key).allMatches(normalized)) {
        if (!listType.any((e) => e['title'] == rule.value && e['isParent'] != 'true')) continue;
        evidence.removeWhere((e) => e.start >= occurrence.start && e.end <= occurrence.end);
        evidence.add(_CategoryEvidence(occurrence.start, occurrence.end, rule.value, 0.99));
      }
    }
    final ambiguousTerms = <String>[];
    final ambiguousSpans = <List<int>>[];
    for (final entry in CategorySemantics.senses.entries) {
      for (final occurrence in RegExp('(?<![a-z0-9])${entry.key}(?![a-z0-9])').allMatches(normalized)) {
        if (actionSpans.any((a) => occurrence.start >= a.start && occurrence.end <= a.end)) continue;
        final wordIndex = tokens.indexWhere((t) => t.start == occurrence.start && t.end == occurrence.end);
        final originalWord = originalWords.length == tokens.length && wordIndex >= 0
            ? originalWords[wordIndex].group(0) : null;
        if (!CategorySemantics.acceptsSpelling(entry.key, originalWord)) {
          evidence.removeWhere((e) => e.start == occurrence.start && e.end == occurrence.end);
          continue;
        }
        // Accented 'kẹo' is candy; unaccented 'keo' can also mean glue.
        if (entry.key == 'keo' && originalWord?.toLowerCase() == 'kẹo') {
          evidence.removeWhere((e) => e.start == occurrence.start && e.end == occurrence.end);
          if (available.containsKey('eating')) evidence.add(_CategoryEvidence(occurrence.start, occurrence.end, 'eating', 0.9));
          continue;
        }
        final qualified = evidence.any((e) => e.start <= occurrence.start &&
            e.end >= occurrence.end && (e.start < occurrence.start || e.end > occurrence.end));
        if (qualified) continue;
        // A local shopping context resolves only an unqualified food noun.
        // It cannot override "mực in" or another item elsewhere in the sentence.
        final before = normalized.substring(0, occurrence.start).trimRight();
        if ({'muc', 'ca', 'ga', 'sua', 'bot', 'hat'}.contains(entry.key) &&
            RegExp(r'\b(?:di cho|o cho|tai cho|sieu thi|hang hai san)(?: mua)?$').hasMatch(before)) {
          evidence.removeWhere((e) => e.start == occurrence.start && e.end == occurrence.end);
          if (available.containsKey('market')) evidence.add(
              _CategoryEvidence(occurrence.start, occurrence.end, 'market', 0.95));
          continue;
        }

        evidence.removeWhere((e) => e.start == occurrence.start && e.end == occurrence.end);
        for (final key in entry.value) {
          if (available.containsKey(key)) {
            evidence.add(_CategoryEvidence(occurrence.start, occurrence.end, key, 0.5));
          }
        }
        ambiguousTerms.add(entry.key);
        ambiguousSpans.add([occurrence.start, occurrence.end]);
      }
    }
    final canClarifySingleTerm = ambiguousSpans.length == 1 &&
        evidence.every((e) => e.start >= ambiguousSpans.first[0] && e.end <= ambiguousSpans.first[1]);
    // A complete product phrase dominates its constituent words only in that
    // same span. It must not override a different item elsewhere in the sentence.
    for (final item in evidence) {
      if (evidence.any((other) => other.start <= item.start && other.end >= item.end &&
          (other.start < item.start || other.end > item.end))) continue;
      if (item.score > (hits[item.key] ?? 0)) hits[item.key] = item.score;
    }
    if (hits.length > 1 && ambiguousTerms.isEmpty) {
      final original = input.toLowerCase();
      final accented = RegExp(r'[à-ỹđ]').hasMatch(original);
      if (accented) {
        final exactKeys = <String>{};
        for (final key in hits.keys) {
          for (final alias in {...?_aliases[key], ...?_expanded[key], ...?offlineCategoryVocabulary[key], ...?categoryKeywordRules[key]}) {
            if (RegExp('(?<![a-zA-ZÀ-ỹĐđ])${RegExp.escape(alias.toLowerCase())}(?![a-zA-ZÀ-ỹĐđ])').hasMatch(original)) {
              exactKeys.add(key);
              break;
            }
          }
        }
        // Only resolve equal-span accent collisions; preserve independent items.
        if (exactKeys.length == 1 && evidence.every((a) => evidence.any((b) =>
        exactKeys.contains(b.key) && b.start <= a.start && b.end >= a.end))) {
          hits.removeWhere((key, _) => !exactKeys.contains(key));
        }
      }
    }
    final result = hits.entries.map((e) => CategoryMatch(
        listType.indexWhere((item) => item['title'] == e.key && item['isParent'] != 'true'),
        e.key, e.value)).toList()
      ..sort((a,b) => b.confidence.compareTo(a.confidence));
    return CategoryAnalysis(result, ambiguousTerms, canClarifySingleTerm);
  }

  static List<CategoryMatch> candidates(String input) => analyze(input).matches;

  static CategoryMatch? find(String input) {
    final matches = candidates(input);
    if (matches.isEmpty) return null;
    if (matches.length > 1) return null;
    return matches.first;
  }

  static String _normalize(String value) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
