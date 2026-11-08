import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:pdfrx_engine/src/native/pdf_file_cache.dart';
import 'package:test/test.dart';

void main() {
  late String? previousCacheDirectory;
  late Directory temp;

  setUp(() async {
    previousCacheDirectory = Pdfrx.cacheDirectoryPath;
    temp = await Directory.systemTemp.createTemp('pdfrx-auth-cache-');
    Pdfrx.cacheDirectoryPath = temp.path;
  });

  tearDown(() async {
    Pdfrx.cacheDirectoryPath = previousCacheDirectory;
    await temp.delete(recursive: true);
  });

  test('a ranged PDF cannot reuse a cache created with another authorization token', () async {
    final uri = Uri.parse('https://example.org/shared-book.pdf');
    final alice = await PdfFileCache.getCacheFilePathForUri(uri, headers: {'Authorization': 'Bearer alice'});
    final bob = await PdfFileCache.getCacheFilePathForUri(uri, headers: {'Authorization': 'Bearer bob'});
    final anonymous = await PdfFileCache.getCacheFilePathForUri(uri);

    expect(alice.path, isNot(bob.path));
    expect(alice.path, isNot(anonymous.path));
    expect(bob.path, isNot(anonymous.path));

    final first = await PdfFileCache.fromUri(uri, headers: {'Authorization': 'Bearer alice'});
    final second = await PdfFileCache.fromUri(uri, headers: {'Authorization': 'Bearer bob'});
    addTearDown(first.close);
    addTearDown(second.close);
    expect(first.filePath, alice.path);
    expect(second.filePath, bob.path);
  });

  test('HTTP header order and casing do not create duplicate caches', () async {
    final uri = Uri.parse('https://example.org/shared-book.pdf');
    final first = await PdfFileCache.getCacheFilePathForUri(uri, headers: {
      'Authorization': 'Bearer alice',
      'X-Tenant': 'library',
    });
    final second = await PdfFileCache.getCacheFilePathForUri(uri, headers: {
      'x-tenant': 'library',
      'authorization': 'Bearer alice',
    });

    expect(first.path, second.path);
  });

  test('headerless requests retain the original URI-only cache key', () async {
    final uri = Uri.parse('https://example.org/ordinary.pdf');
    final plain = await PdfFileCache.getCacheFilePathForUri(uri);
    final empty = await PdfFileCache.getCacheFilePathForUri(uri, headers: {});

    expect(plain.path, empty.path);
  });
}
