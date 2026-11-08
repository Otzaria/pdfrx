import 'dart:async';
import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Only used in the temporary integration-QA branch: Flutter's test runner
  // does not propagate its native assets configuration to background isolates.
  final path = Platform.environment['PDFIUM_PATH'];
  if (path != null) Pdfrx.pdfiumModulePath = path;
  await testMain();
}
