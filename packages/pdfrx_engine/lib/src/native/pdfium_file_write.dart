import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'pdfium_io_result.dart';
import 'pthread/file_write.dart';
import 'win32/file_write.dart';

class PdfiumFileWrite {
  PdfiumFileWrite._();

  /// Creates a file write structure for PDFium with the provided write function.
  static Future<PdfiumFileWrite> create(FutureOr<int> Function(Uint8List buffer, int position, int size) write) async {
    final fw = PdfiumFileWrite._();
    // FPDF_FILEWRITE.WriteBlock supplies only (buffer, size), not a file offset.
    void writeAndSignal(Pointer<Uint8> buffer, int size) async {
      try {
        final writtenSize = await write(buffer.asTypedList(size), 0, size);
        PdfiumFileWriteHelper.instance.setValue(fw.fileWrite, pdfiumTransferStatus(writtenSize, size));
      } catch (e) {
        PdfiumFileWriteHelper.instance.setValue(fw.fileWrite, 0);
      }
    }

    fw._nativeCallable = _NativeFileWriteCallable.listener(writeAndSignal);
    try {
      fw.fileWrite = await PdfiumFileWriteHelper.instance.create(fw._nativeCallable.nativeFunction.address);
      return fw;
    } catch (_) {
      fw._nativeCallable.close();
      rethrow;
    }
  }

  /// Disposes the file write structure and associated resources.
  void dispose() {
    PdfiumFileWriteHelper.instance.destroy(fileWrite);
    _nativeCallable.close();
  }

  /// Address of `FPDF_FILEWRITE` structure.
  late final int fileWrite;
  late final _NativeFileWriteCallable _nativeCallable;
}

typedef _NativeFileWriteCallable = NativeCallable<Void Function(Pointer<Uint8>, IntPtr)>;

/// Abstract interface for platform-specific file write implementations.
abstract class PdfiumFileWriteHelper {
  Future<int> create(int writeBlock);

  void destroy(int fwAddress);

  void setValue(int fwAddress, int value);

  static PdfiumFileWriteHelper get instance {
    // ignore: prefer_conditional_expression
    if (_instance == null) {
      if (Platform.isWindows) {
        _instance = PdfiumFileWriteHelperWin32();
      } else if (Platform.isAndroid || Platform.isLinux || Platform.isIOS || Platform.isMacOS) {
        _instance = PdfiumFileWriteHelperPthread();
      } else {
        throw UnsupportedError('PdfiumFileWriteHelper is not implemented for this platform.');
      }
    }
    return _instance!;
  }

  static PdfiumFileWriteHelper? _instance;
}
