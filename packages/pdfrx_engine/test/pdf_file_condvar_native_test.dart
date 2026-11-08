import 'dart:io';
import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  setUp(() => pdfrxInitialize(tmpPath: tmpRoot.path));

  test('repeated deferred custom reads complete and preserve page rendering', () async {
    final bytes = await File('../pdfrx/example/viewer/assets/hello.pdf').readAsBytes();
    for (var iteration = 0; iteration < 8; iteration++) {
      var reads = 0;
      final doc = await PdfDocument.openCustom(
        fileSize: bytes.length,
        sourceName: 'custom:condvar-$iteration.pdf',
        maxSizeToCacheOnMemory: 0,
        read: (Uint8List buffer, int position, int size) async {
          reads++;
          await Future<void>.delayed(const Duration(microseconds: 250));
          buffer.setRange(0, size, bytes, position);
          return size;
        },
      ).timeout(const Duration(seconds: 10));
      try {
        final image = await doc.pages.first.render();
        expect(image, isNotNull);
        image?.dispose();
        expect(reads, greaterThan(0));
      } finally {
        await doc.dispose();
      }
    }
  });
}
