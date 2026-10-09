import 'dart:math' as math;

import '../models/product.dart';
import 'telugu_transliterator.dart';

/// Matches customer search input against a product's English name, Telugu
/// name, and owner-maintained aliases (Product.searchAliases - see the
/// "Also search as" field in the owner product form), so a customer isn't
/// required to type the exact name stored in the database. Covers:
///   - English names ("tomato") and Telugu script ("టమాటా") - both already
///     live on the product (name / nameTe), just matched as substrings here.
///   - Telugu words typed in English letters ("tamata", "ragulu") - these
///     don't appear in either of the above, so they rely on the aliases
///     field the owner fills in.
///   - English/Telugu mixed queries ("ragi millet") - handled by requiring
///     each word the customer typed to be found somewhere, rather than the
///     whole query as one literal string.
///   - Spelling variations ("raagulu" vs "ragulu") - small typos are
///     tolerated via edit-distance, so near-misses of whatever IS in
///     name/nameTe/aliases still resolve without needing every variant
///     spelled out explicitly.
class SearchMatcher {
  SearchMatcher._();

  static String normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _words(String s) => normalize(s)
      .split(RegExp(r'[,\s]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// True if [product] is a reasonable match for the customer's (raw,
  /// not-yet-normalized) search text.
  static bool matches(Product product, String rawQuery) {
    final query = normalize(rawQuery);
    if (query.isEmpty) return true;

    // Phonetic Latin spelling of the Telugu name (see
    // TeluguTransliterator) is what makes a query like "pesara pappu"
    // resolve against "పెసర పప్పు" automatically, for every product in
    // the catalog, without each transliteration needing to be hand-added
    // as an alias first.
    final romanizedNameTe = product.nameTe != null
        ? TeluguTransliterator.romanize(product.nameTe!)
        : '';
    final haystack = normalize(
      [
        product.name,
        product.nameTe ?? '',
        romanizedNameTe,
        product.searchAliases ?? '',
      ].join(' '),
    );

    // Fast path: the whole query appears verbatim somewhere - covers exact
    // names, Telugu script, and multi-word aliases like "finger millet" in
    // one check, without the word-by-word logic below.
    if (haystack.contains(query)) return true;

    final haystackWords = _words(haystack);
    final queryWords = _words(query);
    return queryWords.every(
      (qWord) => haystackWords.any((hWord) => _wordMatches(qWord, hWord)),
    );
  }

  static bool _wordMatches(String query, String candidate) {
    if (candidate.contains(query)) return true;
    // Typo tolerance only kicks in for reasonably long words - short words
    // (<=3 chars) are too easy to false-positive-match against unrelated
    // short words at edit-distance 1 (e.g. "pea" vs "tea").
    if (query.length <= 3) return false;
    final maxDistance = query.length <= 5 ? 1 : 2;
    return _levenshtein(query, candidate) <= maxDistance;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      final tmp = previous;
      previous = current;
      current = tmp;
    }
    return previous[b.length];
  }
}
