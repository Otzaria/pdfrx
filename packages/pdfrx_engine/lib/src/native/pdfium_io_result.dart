/// PDFium's GetBlock/WriteBlock callbacks return a success flag, not a byte count.
///
/// A partial transfer must be reported as a failure: PDFium assumes the whole
/// requested buffer is initialized once the callback reports success.
int pdfiumTransferStatus(int transferredBytes, int requestedBytes) =>
    transferredBytes == requestedBytes ? 1 : 0;
