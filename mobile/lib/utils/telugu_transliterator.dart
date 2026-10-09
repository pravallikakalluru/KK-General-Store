/// Converts Telugu script to its phonetic Latin-letter spelling, so a
/// customer typing a Telugu word in English letters ("pesara pappu") can be
/// matched against a product's Telugu name (పెసర పప్పు) without that exact
/// spelling needing to be hand-entered anywhere - this is the same trick
/// apps like Blinkit rely on (a real transliteration of the script, not a
/// hand-maintained word list) and is what makes multilingual search scale
/// to the whole catalog instead of only the handful of words anyone
/// thought to add as aliases.
///
/// Telugu is an abugida: every consonant carries an inherent "a" sound
/// unless followed by a vowel sign (matra, which replaces it) or a virama
/// (which cancels it, used to stack consonants into a conjunct). Scanning
/// character-by-character and applying those three rules reproduces how
/// the word is actually pronounced - e.g. పప్పు decomposes as ప(pa) +
/// ప(p, cancelled vowel) + ప(pu, carries the ు matra) = "pa"+"p"+"pu" =
/// "pappu".
class TeluguTransliterator {
  TeluguTransliterator._();

  static const _virama = '్';
  static const _anusvara = 'ం';
  static const _visarga = 'ః';
  static const _candrabindu = 'ఁ';

  static const Map<String, String> _independentVowels = {
    'అ': 'a', 'ఆ': 'a', 'ఇ': 'i', 'ఈ': 'i', 'ఉ': 'u', 'ఊ': 'u',
    'ఋ': 'ru', 'ౠ': 'ru', 'ఎ': 'e', 'ఏ': 'e', 'ఐ': 'ai',
    'ఒ': 'o', 'ఓ': 'o', 'ఔ': 'au',
  };

  // Base consonant sound, with the inherent "a" NOT included - callers add
  // it back unless a matra/virama says otherwise.
  static const Map<String, String> _consonants = {
    'క': 'k', 'ఖ': 'kh', 'గ': 'g', 'ఘ': 'gh', 'ఙ': 'ng',
    'చ': 'ch', 'ఛ': 'chh', 'జ': 'j', 'ఝ': 'jh', 'ఞ': 'ny',
    'ట': 't', 'ఠ': 'th', 'డ': 'd', 'ఢ': 'dh', 'ణ': 'n',
    'త': 't', 'థ': 'th', 'ద': 'd', 'ధ': 'dh', 'న': 'n',
    'ప': 'p', 'ఫ': 'ph', 'బ': 'b', 'భ': 'bh', 'మ': 'm',
    'య': 'y', 'ర': 'r', 'ల': 'l', 'వ': 'v',
    'శ': 'sh', 'ష': 'sh', 'స': 's', 'హ': 'h', 'ళ': 'l', 'ఱ': 'r',
  };

  // Labial consonants - anusvara before one of these nasalizes as "m"
  // ("sampada"); before everything else (velar/palatal/retroflex/dental -
  // "bangala", "kandi", "sangu") it nasalizes as "n". Standard Sanskrit/
  // Telugu anusvara sandhi, simplified to a two-way split since the finer
  // "ṅ"/"ñ"/"ṇ" distinctions are never how anyone actually types these.
  static const _labials = {'ప', 'ఫ', 'బ', 'భ', 'మ'};

  // Vowel sign (matra) sound - replaces the consonant's inherent "a".
  static const Map<String, String> _matras = {
    'ా': 'a', 'ి': 'i', 'ీ': 'i', 'ు': 'u', 'ూ': 'u', 'ృ': 'ru',
    'ె': 'e', 'ే': 'e', 'ై': 'ai', 'ొ': 'o', 'ో': 'o', 'ౌ': 'au',
  };

  /// Romanizes [text] (assumed to contain Telugu script, possibly mixed
  /// with spaces/punctuation/already-Latin text, which pass through
  /// unchanged). Vowel length (short vs long) is deliberately collapsed
  /// (ా and అ both become "a") since customers typing phonetically never
  /// reliably distinguish them either - keeping search forgiving matters
  /// more here than transliteration purity.
  static String romanize(String text) {
    final buffer = StringBuffer();
    final chars = text.characters_;
    var i = 0;
    while (i < chars.length) {
      final ch = chars[i];
      final consonantBase = _consonants[ch];
      if (consonantBase != null) {
        final next = i + 1 < chars.length ? chars[i + 1] : null;
        if (next == _virama) {
          buffer.write(consonantBase);
          i += 2; // consume the consonant and the virama
          continue;
        }
        final matra = next != null ? _matras[next] : null;
        if (matra != null) {
          buffer.write(consonantBase + matra);
          i += 2; // consume the consonant and its vowel sign
          continue;
        }
        buffer.write('${consonantBase}a'); // inherent vowel
        i += 1;
        continue;
      }

      final vowel = _independentVowels[ch];
      if (vowel != null) {
        buffer.write(vowel);
        i += 1;
        continue;
      }

      if (ch == _anusvara) {
        final next = i + 1 < chars.length ? chars[i + 1] : null;
        final nextIsConsonant = next != null && _consonants.containsKey(next);
        buffer.write(
          nextIsConsonant && !_labials.contains(next) ? 'n' : 'm',
        );
        i += 1;
        continue;
      }
      if (ch == _visarga) {
        buffer.write('h');
        i += 1;
        continue;
      }
      if (ch == _candrabindu) {
        buffer.write('m');
        i += 1;
        continue;
      }

      // Not Telugu script (space, English letters, punctuation, digits) -
      // pass through as-is so mixed-language text and word boundaries
      // survive unchanged.
      buffer.write(ch);
      i += 1;
    }
    return buffer.toString();
  }
}

extension _TeluguChars on String {
  /// Splits into Unicode scalar units (not UTF-16 code units) so
  /// single-codepoint Telugu characters are never misread as a surrogate
  /// pair - Telugu's block (U+0C00-U+0C7F) is within the BMP so this is
  /// mostly a formality, but it's the correct way to iterate either way.
  List<String> get characters_ => runes.map(String.fromCharCode).toList();
}
