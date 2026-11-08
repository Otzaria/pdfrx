import 'dart:io';
import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:pdfrx_engine/src/native/pdf_file_cache.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late PdfFileCache cache;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pdfrx-disk-read-test-');
    cache = PdfFileCache(File('${temp.path}/test.cache'));
    cache.setBlockSize(4);
    await cache.initializeWithFileSize(8, truncateExistingContent: true);
  });

  tearDown(() async {
    await cache.close();
    await temp.delete(recursive: true);
  });

  test('a missing cache block raises instead of returning unread zero bytes', () async {
    final buffer = Uint8List.fromList(List.filled(8, 0xff));
    await expectLater(cache.read(buffer, 0, 0, 8), throwsA(isA<PdfException>()));
  });

  test('a complete cache read returns the exact requested bytes', () async {
    await cache.write(0, [1, 2, 3, 4]);
    await cache.write(4, [5, 6, 7, 8]);
    final buffer = Uint8List(8);
    await cache.read(buffer, 0, 0, 8);
    expect(buffer, [1, 2, 3, 4, 5, 6, 7, 8]);
  });
}
