import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:pdfrx_engine/src/native/pdf_file_cache.dart';
import 'package:test/test.dart';

class _Document implements PdfDocument {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadingBackend implements PdfrxEntryFunctions {
  Uint8List? received;

  @override
  Future<PdfDocument> openCustom({
    required FutureOr<int> Function(Uint8List buffer, int position, int size) read,
    required int fileSize,
    required String sourceName,
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
    int? maxSizeToCacheOnMemory,
    void Function()? onDispose,
  }) async {
    final data = Uint8List(fileSize);
    await read(data, 0, fileSize);
    received = data;
    onDispose?.call();
    return _Document();
  }

  @override
  Future<PdfDocument> openFile(
    String filePath, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
  }) async => _Document();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final uri = Uri.parse('https://example.org/book.pdf');

  Future<({PdfFileCache cache, _ReadingBackend backend})> fixture(
    Future<http.Response> Function(http.Request request) respond,
  ) async {
    final directory = await Directory.systemTemp.createTemp('pdfrx-range-test-');
    final cache = await PdfFileCache.fromFile(File(directory.path + '/book.cache'));
    final oldClientFactory = Pdfrx.createHttpClient;
    Pdfrx.createHttpClient = () => MockClient(respond);
    addTearDown(() async {
      Pdfrx.createHttpClient = oldClientFactory;
      await cache.close();
      await directory.delete(recursive: true);
    });
    return (cache: cache, backend: _ReadingBackend());
  }

  test('reads adjacent validated ranges without shifting cached bytes', () async {
    final seenRanges = <String?>[];
    final f = await fixture((request) async {
      final range = request.headers['range'];
      seenRanges.add(range);
      if (range == 'bytes=0-3') {
        return http.Response.bytes(ascii.encode('ABCD'), 206, headers: {'content-range': 'bytes 0-3/8'});
      }
      if (range == 'bytes=4-7') {
        return http.Response.bytes(ascii.encode('EFGH'), 206, headers: {'content-range': 'bytes 4-7/8'});
      }
      throw StateError('Unexpected Range: $range');
    });

    await pdfDocumentFromUri(uri, cache: f.cache, blockSize: 4, entryFunctions: f.backend);
    expect(ascii.decode(f.backend.received!), 'ABCDEFGH');
    expect(seenRanges, ['bytes=0-3', 'bytes=4-7']);
    expect(f.cache.isFullyCached, isTrue);
  });

  test('rejects a 206 response with missing Content-Range', () async {
    final f = await fixture((_) async => http.Response.bytes(ascii.encode('ABCD'), 206));
    await expectLater(
      pdfDocumentFromUri(uri, cache: f.cache, blockSize: 4, entryFunctions: f.backend),
      throwsA(isA<PdfException>()),
    );
    expect(f.cache.isFullyCached, isFalse);
  });

  test('rejects a short 206 body rather than reading a sparse hole', () async {
    final f = await fixture(
      (_) async => http.Response.bytes(ascii.encode('AB'), 206, headers: {'content-range': 'bytes 0-3/8'}),
    );
    await expectLater(
      pdfDocumentFromUri(uri, cache: f.cache, blockSize: 4, entryFunctions: f.backend),
      throwsA(isA<PdfException>()),
    );
    expect(f.cache.isCached(0), isFalse);
  });

  test('rejects wrong-offset ranged responses on later reads', () async {
    final f = await fixture((request) async {
      if (request.headers['range'] == 'bytes=0-3') {
        return http.Response.bytes(ascii.encode('ABCD'), 206, headers: {'content-range': 'bytes 0-3/8'});
      }
      return http.Response.bytes(ascii.encode('EFGH'), 206, headers: {'content-range': 'bytes 0-3/8'});
    });
    await expectLater(
      pdfDocumentFromUri(uri, cache: f.cache, blockSize: 4, entryFunctions: f.backend),
      throwsA(isA<PdfException>()),
    );
    expect(f.cache.isCached(1), isFalse);
  });

  test('does not append a full 200 response to a requested later block', () async {
    final f = await fixture((request) async {
      if (request.headers['range'] == 'bytes=0-3') {
        return http.Response.bytes(ascii.encode('ABCD'), 206, headers: {'content-range': 'bytes 0-3/8'});
      }
      return http.Response.bytes(ascii.encode('ABCDEFGH'), 200);
    });
    await expectLater(
      pdfDocumentFromUri(uri, cache: f.cache, blockSize: 4, entryFunctions: f.backend),
      throwsA(isA<PdfException>()),
    );
    expect(f.cache.isCached(1), isFalse);
  });
}
