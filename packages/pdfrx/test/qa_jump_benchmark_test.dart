// Temporary, unmerged A/B instrumentation for upstream pdfrx#798.
// Uses exactly the same document, viewport, cache budget and jumps on both
// the app-pinned baseline and the proposed prefetch branch.
// The matching PDF viewer QA instrumentation prints the completed preview time.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => pdfrxInitialize());

  for (final scenario in ['text', 'scan']) {
    testWidgets('JUMP_BENCH $scenario top-anchor extent1 DPR2 native PDFium', (tester) async {
    tester.view.physicalSize = const Size(2560, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final document = (await tester.runAsync(
      () => PdfDocument.openFile(scenario == 'scan' ? 'test/assets/qa_scanned40.pdf' : 'test/assets/multipage40.pdf', useProgressiveLoading: false),
    ))!;
    addTearDown(document.dispose);
    expect(document.pages.length, 40);

    final budget = PdfImageCacheBudget(maximumBytes: 96 * 1024 * 1024);
    addTearDown(budget.dispose);
    final controller = PdfViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewer(
          PdfDocumentRefDirect(document, autoDispose: false),
          controller: controller,
          params: PdfViewerParams(
            imageCacheBudget: budget,
            maxImageBytesCachedOnMemory: 48 * 1024 * 1024,
            horizontalCacheExtent: 0,
            verticalCacheExtent: 1,
            sizeDelegateProvider:
                PdfViewerSizeDelegateProviderLegacy(calculateInitialZoom: (_, _, _, _) => 1),
            getPageRenderingScale: (_, _, _, _) => 2,
            behaviorControlParams: const PdfViewerBehaviorControlParams(
              pageImageCachingDelay: Duration.zero,
              partialImageLoadingDelay: Duration.zero,
              trailingPageLoadingDelay: Duration.zero,
            ),
          ),
        ),
      ),
    );

    Future<void> frame() async {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }

    for (var i = 0; i < 100 && !controller.isReady; i++) {
      await frame();
    }
    expect(controller.isReady, isTrue);
    for (var i = 0; i < 35; i++) {
      await frame();
    }
    print('JUMP_BENCH_READY scenario=$scenario at_us=${DateTime.now().microsecondsSinceEpoch} pages=${document.pages.length}');

    for (final target in [12, 25, 36, 7, 30, 18]) {
      final start = DateTime.now().microsecondsSinceEpoch;
      print('JUMP_BENCH_START scenario=$scenario page=$target at_us=$start');
      await controller.goToPage(
        pageNumber: target,
        anchor: PdfPageAnchor.top,
        duration: Duration.zero,
      );
      for (var i = 0; i < 75; i++) {
        await frame();
      }
      print('JUMP_BENCH_SETTLED scenario=$scenario page=$target at_us=${DateTime.now().microsecondsSinceEpoch} '
          'retained=${budget.retainedBytes} pending=${budget.pendingBytes}');
      expect(controller.pageNumber, target);
      expect(tester.takeException(), isNull);
    }

    print('JUMP_BENCH_PEAK scenario=$scenario estimated=${budget.peakEstimatedBytes} limit=${budget.maximumBytes}');
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 15; i++) {
      await frame();
    }
    });
  }
}
