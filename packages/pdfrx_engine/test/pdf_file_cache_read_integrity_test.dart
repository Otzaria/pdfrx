import 'dart:io';
import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:pdfrx_engine/src/native/pdf_file_cache.dart';
import 'package:test/test.dart';

void main() {
  test('short disk cache reads are rejected instead of returning zero-filled page data', () async {
    final directory = await Directory.systemTemp.createTemp('pdfrx-short-read-');
    addTearDown(() async => directory.delete(recursive: true));
    final file = File('${directory.path}/cache.pdf');
    final cache = PdfFileCache(file);
    addTearDown(cache.close);

    expect(cache.setBlockSize(4), isTrue);
    await cache.initializeWithFileSize(8, truncateExistingContent: true);
    await cache.write(0, [1, 2, 3, 4]);
    await cache.setCached(0);
    final fullSize = await file.length();
    await cache.close();

    // The metadata still claims the block is cached, but the file was
    // truncated by a crash, disk cleanup or external process.
    final handle = await file.open(mode: FileMode.append);
    await handle.truncate(fullSize - 2);
    await handle.close();
    final buffer = Uint8List(4);
    await expectLater(cache.read(buffer, 0, 0, 4), throwsA(isA<PdfException>()));
  });

  test('intact cache reads preserve the exact byte range', () async {
    final directory = await Directory.systemTemp.createTemp('pdfrx-full-read-');
    addTearDown(() async => directory.delete(recursive: true));
    final cache = PdfFileCache(File('${directory.path}/cache.pdf'));
    addTearDown(cache.close);
    cache.setBlockSize(4);
    await cache.initializeWithFileSize(8, truncateExistingContent: true);
    await cache.write(0, [10, 20, 30, 40, 50, 60, 70, 80]);
    final buffer = Uint8List(3);
    await cache.read(buffer, 0, 3, 3);
    expect(buffer, [40, 50, 60]);
  });
}
