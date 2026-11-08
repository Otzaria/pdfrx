import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

void main() {
  test('empty pages safely reject fragment lookups and range geometry', () {
    const empty = PdfPageText(pageNumber: 1, fullText: '', charRects: [], fragments: []);
    expect(empty.getFragmentIndexForTextIndex(0), 0);
    expect(empty.getFragmentIndexForTextIndex(-1), -1);
    expect(empty.getFragmentIndexForTextIndex(1), -1);
    expect(empty.getFragmentForTextIndex(1), isNull);
    expect(() => empty.getRangeFromAB(0, 0), throwsRangeError);

    const range = PdfPageTextRange(pageText: empty, start: 0, end: 0);
    expect(range.enumerateFragmentBoundingRects().toList(), isEmpty);
  });

  test('missing fragments in a nonempty text layer do not throw', () {
    const text = PdfPageText(pageNumber: 1, fullText: 'abc', charRects: [], fragments: []);
    expect(text.getFragmentIndexForTextIndex(0), -1);
    expect(text.getFragmentIndexForTextIndex(2), -1);
    expect(text.getFragmentIndexForTextIndex(3), 0);
    expect(text.getFragmentIndexForTextIndex(4), -1);

    const range = PdfPageTextRange(pageText: text, start: 0, end: 1);
    expect(range.enumerateFragmentBoundingRects().toList(), isEmpty);
  });

  test('the exclusive end of text is not a valid inclusive character index', () {
    final page = PdfPageText(
      pageNumber: 1,
      fullText: 'abc',
      charRects: [for (var i = 0; i < 3; i++) PdfRect(i.toDouble(), 1, i + 1.0, 0)],
      fragments: const [],
    );
    expect(page.getRangeFromAB(2, 1).text, 'bc');
    expect(() => page.getRangeFromAB(3, 3), throwsRangeError);
    expect(() => page.getRangeFromAB(0, 3), throwsRangeError);
    expect(() => page.getRangeFromAB(-1, 0), throwsRangeError);
  });
}
