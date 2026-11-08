import 'dart:collection';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

class _CountingRectList extends ListBase<PdfRect> {
  _CountingRectList(this.values);
  final List<PdfRect> values;
  int reads = 0;

  @override
  int get length => values.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  PdfRect operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, PdfRect value) => throw UnsupportedError('read only');
}

void main() {
  test('a selected character near the end of a large page needs only its own rect', () {
    final boxes = _CountingRectList([for (var i = 0; i < 10000; i++) PdfRect(i.toDouble(), 10, i + 1.0, 0)]);

    expect(boxes.boundingRect(start: 9998, end: 10000), const PdfRect(9998, 10, 10000, 0));
    expect(boxes.reads, lessThanOrEqualTo(4));
  });

  test('indexed and non-list iterable bounds preserve the same geometry', () {
    final boxes = [
      const PdfRect(1, 3, 2, 2),
      const PdfRect(4, 8, 5, 3),
      const PdfRect(0, 5, 3, 1),
      const PdfRect(8, 2, 9, 0),
    ];
    final expected = const PdfRect(0, 8, 5, 1);

    expect(boxes.boundingRect(start: 1, end: 3), expected);
    expect(boxes.where((_) => true).boundingRect(start: 1, end: 3), expected);
    expect(boxes.boundingRect(start: 2, end: 50), const PdfRect(0, 5, 9, 0));
    expect(() => boxes.boundingRect(start: 5, end: 6), throwsStateError);
    expect(() => boxes.boundingRect(start: 0, end: 0), throwsStateError);
  });
}
