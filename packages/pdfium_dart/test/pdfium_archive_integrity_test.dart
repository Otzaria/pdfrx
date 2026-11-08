import 'dart:convert';

import 'package:test/test.dart';

import '../lib/src/pdfium_archive_integrity.dart';

void main() {
  test('pinned chromium/8125 checksums cover all supported platform archives', () {
    expect(pdfium8125AssetSha256, hasLength(13));
    for (final platform in ['android', 'linux', 'mac', 'win']) {
      expect(
        pdfium8125AssetSha256.keys.any((name) => name.startsWith('pdfium-$platform-')),
        isTrue,
      );
    }
    expect(
      pdfium8125AssetSha256['pdfium-linux-x64.tgz'],
      'e1c3ce6e270cb5e0c20816b379ad9f2c1309972697c505f508de92bf5e7d6659',
    );
    expect(
      pdfium8125AssetSha256['pdfium-win-x64.tgz'],
      '9a964261760cff52570aabf038ab346d3a5034dd8b30d0d5fe8861235d356b8b',
    );
  });

  test('SHA-256 accepts precisely the expected compressed content', () {
    final bytes = utf8.encode('abc');
    expect(
      () => verifyPdfiumSha256(
        bytes,
        archiveName: 'fixture.tgz',
        expectedSha256:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
      returnsNormally,
    );
    expect(
      () => verifyPdfiumSha256(
        utf8.encode('abd'),
        archiveName: 'fixture.tgz',
        expectedSha256:
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      ),
      throwsStateError,
    );
  });

  test('rejects an unpinned or corrupted PDFium download without decoding it', () {
    expect(
      () => verifyPdfium8125Archive('pdfium-linux-x64.tgz', [0x1f, 0x8b, 0]),
      throwsStateError,
    );
    expect(
      () => verifyPdfium8125Archive('pdfium-linux-arm-unsupported.tgz', const []),
      throwsStateError,
    );
    expect(
      () => verifyPdfium8125Archive('pdfium-v8-linux-x64.tgz', const []),
      throwsStateError,
    );
  });
}
