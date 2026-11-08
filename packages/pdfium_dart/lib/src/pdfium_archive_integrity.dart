import 'package:crypto/crypto.dart';

/// Immutable release asset digests published by bblanchon/pdfium-binaries
/// for chromium/8125. These are the compressed *.tgz SHA-256 values, not
/// hashes of the unpacked library and not values from an untrusted response.
const pdfium8125AssetSha256 = <String, String>{
  'pdfium-android-arm.tgz': 'ac4ac5319ded88ba5d885747a6b2641e7f712c9797de0770465104abe4dbf7da',
  'pdfium-android-arm64.tgz': '0495e57163429937caaee1bdd9b07924a7098dbd51d1b97645d124e349f097b4',
  'pdfium-android-x64.tgz': 'bd68707f29f2316c20f9d5c793b8731796a4a65408ac4d3c30bc606390354e41',
  'pdfium-android-x86.tgz': '9d4f7edf5b46e1ab155d9da3e56520f2554900997c74e21951f524ea7928c622',
  'pdfium-linux-arm.tgz': '4f86498cf83aa62c4892b30d7041e16de2f1ac6099cd117982561222b54618ff',
  'pdfium-linux-arm64.tgz': '8b8818f2ec57d1b213d952ca6d7f0ffeca9d0110487d0e20ad83ba918bc92efa',
  'pdfium-linux-x64.tgz': 'e1c3ce6e270cb5e0c20816b379ad9f2c1309972697c505f508de92bf5e7d6659',
  'pdfium-linux-x86.tgz': '890ccf6a0eef4440c4b6bb213bca6e11d593111deb77875dd6153ac72ff3a11a',
  'pdfium-mac-arm64.tgz': '4939bd935ac83ddc09a3a4f038bc43a19cea1660316a3667f26cb07a070e139d',
  'pdfium-mac-x64.tgz': '8a5193535b80c7215d8932f6647ae5097465b6dba2811602c21e120c2af112b0',
  'pdfium-win-arm64.tgz': 'd394ba61991fb53f4d87f70988035f337d9e73f2bd2c3c1b966df8c43fcabb05',
  'pdfium-win-x64.tgz': '9a964261760cff52570aabf038ab346d3a5034dd8b30d0d5fe8861235d356b8b',
  'pdfium-win-x86.tgz': '5aa1eb3e7de0589534245a181cb51def90d1dc76e987aea4be524a8cb3db1069',
};

/// Checks the entire compressed archive before any extracted native code is
/// placed in the build output. The caller applies this to direct and fallback
/// downloads identically.
void verifyPdfium8125Archive(String archiveName, List<int> archiveBytes) {
  final expected = pdfium8125AssetSha256[archiveName];
  if (expected == null) {
    throw StateError('No pinned PDFium chromium/8125 SHA-256 for $archiveName');
  }
  verifyPdfiumSha256(archiveBytes, expectedSha256: expected, archiveName: archiveName);
}

/// Exposed to unit tests to cover valid, corrupt, and empty archive bodies.
void verifyPdfiumSha256(
  List<int> archiveBytes, {
  required String expectedSha256,
  required String archiveName,
}) {
  final actual = sha256.convert(archiveBytes).toString();
  if (actual != expectedSha256) {
    throw StateError(
      'PDFium SHA-256 mismatch for $archiveName: expected $expectedSha256, received $actual',
    );
  }
}
