import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

/// One line at [y]: each character gets a 10pt-wide box at the given x.
PdfPageRawText _line(List<(String, double)> glyphs, {double y = 700}) {
  final text = StringBuffer();
  final rects = <PdfRect>[];
  for (final (char, x) in glyphs) {
    text.write(char);
    rects.add(PdfRect(x, y + 10, x + 10, y));
  }
  return PdfPageRawText(text.toString(), rects);
}

/// [words] laid out right to left, as a reader sees them; letters of each word
/// are placed right to left too.
List<(String, double)> _layoutRtl(List<String> words, {double right = 500}) {
  final glyphs = <(String, double)>[];
  var x = right;
  for (var w = 0; w < words.length; w++) {
    if (w > 0) {
      x -= 10;
      glyphs.add((' ', x));
    }
    for (final ch in words[w].split('')) {
      x -= 10;
      glyphs.add((ch, x));
    }
  }
  return glyphs;
}

void main() {
  const words = ['שלום', 'עולם', 'ומלואו'];

  test('logical order is returned untouched', () {
    final raw = _line(_layoutRtl(words));
    expect(identical(PdfHebrewTextNormalizer.normalize(raw), raw), isTrue);
  });

  test('words stored left to right are reordered, letters kept', () {
    // OCR layers: every word is logical, but the line runs left to right.
    final logical = _layoutRtl(words);
    final wordRuns = <List<(String, double)>>[];
    var current = <(String, double)>[];
    for (final g in logical) {
      if (g.$1 == ' ') {
        wordRuns.add(current);
        current = [];
      } else {
        current.add(g);
      }
    }
    wordRuns.add(current);
    final visual = <(String, double)>[];
    for (final run in wordRuns.reversed) {
      if (visual.isNotEmpty) visual.add((' ', run.first.$2 + 10));
      visual.addAll(run);
    }
    final raw = _line(visual);
    expect(raw.fullText, 'ומלואו עולם שלום');

    final fixed = PdfHebrewTextNormalizer.normalize(raw);
    expect(fixed.fullText, 'שלום עולם ומלואו');
    // Boxes travel with their characters.
    expect(fixed.charRects.first, raw.charRects[raw.fullText.indexOf('ש')]);
  });

  test('a line stored fully in visual order is reversed', () {
    // Every glyph in left-to-right order: letters and words both backwards.
    final logical = _layoutRtl(words);
    final visual = logical.reversed.toList();
    final raw = _line(visual);
    expect(raw.fullText, 'ואולמו םלוע םולש');
    expect(PdfHebrewTextNormalizer.normalize(raw).fullText, 'שלום עולם ומלואו');
  });

  test('points stay after their letter when a word is reversed', () {
    // שָׁלוֹם stored letter by letter left to right, each point after its letter.
    final glyphs = <(String, double)>[
      ('ם', 100),
      ('ו', 110),
      ('ֹ', 110),
      ('ל', 120),
      ('ש', 130),
      ('ָ', 130),
      ('ׁ', 130),
      (' ', 140),
      ('ה', 150),
      ('ז', 160),
      (' ', 170),
      ('ר', 180),
      ('פ', 190),
      ('ס', 200),
    ];
    final fixed = PdfHebrewTextNormalizer.normalize(_line(glyphs));
    expect(fixed.fullText, 'ספר זה שָׁלוֹם');
  });

  test('Windows-1255 read as Latin-1 is decoded', () {
    const latin1 = {'ש': 'ù', 'ל': 'ì', 'ו': 'å', 'ם': 'í', 'ע': 'ò', 'מ': 'î', 'א': 'à'};
    String encode(String s) => s.split('').map((c) => latin1[c] ?? c).join();
    final many = List.filled(4, words).expand((w) => w).toList();
    final glyphs = _layoutRtl(many).map((g) => (encode(g.$1), g.$2)).toList();
    final raw = _line(glyphs);
    expect(PdfHebrewTextNormalizer.normalize(raw), same(raw));
    final fixed = PdfHebrewTextNormalizer.normalize(raw, decodeLegacyEncoding: true);
    expect(fixed.fullText, many.join(' '));
  });

  test('Latin text with accents is not decoded', () {
    const french = 'déjà là où élève réécrire';
    var x = 50.0;
    final glyphs = [for (final ch in french.split('')) (ch, x += 10)];
    final raw = _line(glyphs);
    expect(PdfHebrewTextNormalizer.normalize(raw).fullText, french);
  });

  test('a two-word line follows the page majority', () {
    // Page evidence: a long visual line; a short line alone would be ambiguous.
    final long = _layoutRtl(words).reversed.toList();
    final short = _layoutRtl(['ספר', 'אחד'], right: 300).reversed.toList();
    final text = StringBuffer();
    final rects = <PdfRect>[];
    for (final (ch, x) in long) {
      text.write(ch);
      rects.add(PdfRect(x, 710, x + 10, 700));
    }
    text.write('\n');
    rects.add(const PdfRect(0, 0, 0, 0));
    for (final (ch, x) in short) {
      text.write(ch);
      rects.add(PdfRect(x, 690, x + 10, 680));
    }
    final fixed = PdfHebrewTextNormalizer.normalize(PdfPageRawText(text.toString(), rects));
    expect(fixed.fullText.split('\n'), ['שלום עולם ומלואו', 'ספר אחד']);
  });

  test('accent-heavy Latin text is left untouched when legacy decoding is disabled', () {
    final text = List.filled(30, 'é').join();
    final raw = _line([for (var i = 0; i < text.length; i++) (text[i], i * 10.0)]);
    expect(PdfHebrewTextNormalizer.normalize(raw), same(raw));
  });

  void expectMapped(PdfPageRawText raw, [String? expected]) {
    final result = PdfHebrewTextNormalizer.normalize(raw, decodeLegacyEncoding: true);
    if (expected != null) expect(result.fullText, expected);
    expect(result.charRects, hasLength(raw.charRects.length));
    expect(result.charRects, unorderedEquals(raw.charRects));
    for (var i = 0; i < result.charRects.length; i++) {
      final original = raw.charRects.indexOf(result.charRects[i]);
      expect(original, greaterThanOrEqualTo(0));
      expect(result.fullText[i], raw.fullText[original]);
    }
  }

  test('visual mixed tokens retain the established Hebrew search and glyph mapping', () {
    for (final text in ['1םולש', '123םולש', 'םולש123', 'abcםולש', 'םולשabc']) {
      final raw = _line([for (var i = 0; i < text.length; i++) (text[i], i * 10.0)]);
      expectMapped(raw, text == '1םולש' ? 'שלום1' : null);
      expect(PdfHebrewTextNormalizer.normalize(raw).fullText, contains('שלום'));
    }
  });

  test('scanned Sanhedrin page 7 preserves phrase search and character mapping', () {
    final raw = PdfPageRawText('16 מחה ו היה א אם כיץ 4', [
      PdfRect(356.1709289550781, 742.00588378869, 358.05413818359375, 738.474877929315),
      PdfRect(358.086181640625, 742.0165649410337, 360.3706359863281, 738.4267211910337),
      PdfRect(347.0711669921875, 735.8248535152525, 347.0711669921875, 735.8248535152525),
      PdfRect(341.191162109375, 740.52883300744, 345.295166015625, 735.808862304315),
      PdfRect(335.5521545410156, 740.5368286129087, 339.16815185546875, 735.73684081994),
      PdfRect(329.45013427734375, 740.5368286129087, 333.0741271972656, 735.73684081994),
      PdfRect(400.5381164550781, 735.8248535152525, 400.5381164550781, 735.8248535152525),
      PdfRect(397.7701110839844, 740.5368286129087, 399.0981140136719, 735.7848754879087),
      PdfRect(379.8441162109375, 735.8248535152525, 379.8441162109375, 735.8248535152525),
      PdfRect(374.1401062011719, 740.5368286129087, 377.76409912109375, 735.73684081994),
      PdfRect(371.48211669921875, 740.5208374019712, 372.93011474609375, 737.976831054315),
      PdfRect(366.1741027832031, 740.5368286129087, 369.798095703125, 735.73684081994),
      PdfRect(404.6321716308594, 738.474877929315, 404.6321716308594, 738.474877929315),
      PdfRect(400.80157470703125, 741.6420532222837, 403.5675048828125, 738.41066894494),
      PdfRect(397.6661071777344, 735.8248535152525, 397.6661071777344, 735.8248535152525),
      PdfRect(391.9381103515625, 740.5608764644712, 396.0740966796875, 735.7288452144712),
      PdfRect(386.0740966796875, 740.5208374019712, 389.818115234375, 735.8248535152525),
      PdfRect(566.485107421875, 736.1249023433775, 566.485107421875, 736.1249023433775),
      PdfRect(563.9771118164062, 739.35891113244, 566.298095703125, 736.1249023433775),
      PdfRect(562.3375854492188, 739.3534179683775, 563.3330688476562, 737.6043945308775),
      PdfRect(559.9970703125, 739.35891113244, 562.5160522460938, 735.0854125972837),
      PdfRect(558.880126953125, 736.1249023433775, 558.880126953125, 736.1249023433775),
      PdfRect(556.2000732421875, 739.4148803707212, 558.5200805664062, 736.1249023433775),
    ]);
    expectMapped(raw, 'כיץ 4 א ו אם היה 16 מחה');
  });

  test('scanned Sanhedrin page 84 preserves phrase search and character mapping', () {
    final raw = PdfPageRawText('ישראל 6חטא ליהושע', [
      PdfRect(321.0251159667969, 434.6023156736046, 322.38262939453125, 432.2173059079796),
      PdfRect(314.92462158203125, 434.60982299782336, 319.8896179199219, 430.199819335714),
      PdfRect(309.86962890625, 434.6173303220421, 312.87713623046875, 430.16231323219836),
      PdfRect(304.525146484375, 434.63982177712023, 308.40264892578125, 430.10982299782336),
      PdfRect(299.33514404296875, 436.3573205564171, 302.5001525878906, 430.1023156736046),
      PdfRect(350.9796447753906, 432.699819335714, 350.9796447753906, 432.699819335714),
      PdfRect(348.0146484375, 436.00981689430773, 350.149658203125, 432.6548059079796),
      PdfRect(342.3176574707031, 434.6173303220421, 345.7076416015625, 430.1173303220421),
      PdfRect(336.1226501464844, 434.60982299782336, 339.9476623535156, 430.199819335714),
      PdfRect(330.15216064453125, 434.63982177712023, 334.0296630859375, 430.10982299782336),
      PdfRect(383.6846618652344, 430.199819335714, 383.6846618652344, 430.199819335714),
      PdfRect(378.75714111328125, 436.3573205564171, 381.9221496582031, 430.1023156736046),
      PdfRect(376.40216064453125, 434.6023156736046, 377.7596740722656, 432.2173059079796),
      PdfRect(370.9666748046875, 434.6173303220421, 374.3641662597656, 430.1173303220421),
      PdfRect(367.9966735839844, 434.6173303220421, 369.2416687011719, 430.16231323219836),
      PdfRect(361.9516906738281, 434.60982299782336, 366.91668701171875, 430.199819335714),
      PdfRect(356.3871765136719, 434.6173303220421, 359.97216796875, 430.199819335714),
    ]);
    expectMapped(raw, 'ליהושע 6חטא ישראל');
  });
}
