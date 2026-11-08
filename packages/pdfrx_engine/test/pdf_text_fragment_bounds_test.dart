import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

void main() {
  const rect = PdfRect(0, 10, 1, 0);

  test('unstructured text returns no fragment rather than reading an empty list', () {
    const page = PdfPageText(pageNumber: 1, fullText: 'word', charRects: [rect, rect, rect, rect], fragments: []);

    expect(page.getFragmentIndexForTextIndex(-1), -1);
    expect(page.getFragmentIndexForTextIndex(0), -1);
    expect(page.getFragmentForTextIndex(2), isNull);
    expect(page.getFragmentIndexForTextIndex(4), 0);
    expect(page.getFragmentIndexForTextIndex(5), -1);
  });

  test('inclusive selection endpoints cannot exceed the last character', () {
    const page = PdfPageText(pageNumber: 1, fullText: 'word', charRects: [rect, rect, rect, rect], fragments: []);

    final reversed = page.getRangeFromAB(2, 1);
    expect((reversed.start, reversed.end, reversed.text), (1, 3, 'or'));
    expect(page.getRangeFromAB(3, 3).text, 'd');
    expect(() => page.getRangeFromAB(0, 4), throwsRangeError);
    expect(() => page.getRangeFromAB(-1, 2), throwsRangeError);
  });

  test('empty page accepts only the end-of-text fragment index', () {
    const page = PdfPageText(pageNumber: 1, fullText: '', charRects: [], fragments: []);
    expect(page.getFragmentIndexForTextIndex(0), 0);
    expect(page.getFragmentIndexForTextIndex(-1), -1);
    expect(page.getFragmentIndexForTextIndex(1), -1);
    expect(() => page.getRangeFromAB(0, 0), throwsRangeError);
  });
}
