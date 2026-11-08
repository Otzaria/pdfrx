import 'package:pdfrx_engine/src/native/pdfium_io_result.dart';
import 'package:test/test.dart';

void main() {
  test('PDFium I/O callback succeeds only when all requested bytes transferred', () {
    expect(pdfiumTransferStatus(4096, 4096), 1);
    expect(pdfiumTransferStatus(1, 4096), 0);
    expect(pdfiumTransferStatus(4095, 4096), 0);
    expect(pdfiumTransferStatus(4097, 4096), 0);
    expect(pdfiumTransferStatus(0, 4096), 0);
    expect(pdfiumTransferStatus(-1, 4096), 0);
  });
}
