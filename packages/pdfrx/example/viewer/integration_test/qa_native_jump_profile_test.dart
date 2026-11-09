// QA-only Windows profile A/B. Never promote into the application.
// The same source runs on the app's current PDF viewer policy and on #798.
// Log the target-jump timestamp; PDF viewer QA instrumentation logs the
// completion timestamp of each real native PDFium preview.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PROFILE_JUMP native Windows scanned PDF / top anchor / DPR2', (tester) async {
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openAsset('assets/qa_scanned40.pdf');
    addTearDown(doc.dispose);
    expect(doc.pages.length, 40);

    final budget = PdfImageCacheBudget(maximumBytes: 96 * 1024 * 1024);
    addTearDown(budget.dispose);
    final controller = PdfViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(devicePixelRatio: 2),
            child: PdfViewer(
              PdfDocumentRefDirect(doc, autoDispose: false),
              controller: controller,
              params: PdfViewerParams(
                imageCacheBudget: budget,
                maxImageBytesCachedOnMemory: 48 * 1024 * 1024,
                horizontalCacheExtent: 0,
                verticalCacheExtent: 1,
                pageAnchor: PdfPageAnchor.top,
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
        ),
      ),
    );

    for (var i = 0; i < 200 && !controller.isReady; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.isReady, isTrue);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    print('PROFILE_JUMP_READY dpr=2 pages=${doc.pages.length} '
        'rss=${ProcessInfo.currentRss} at_us=${DateTime.now().microsecondsSinceEpoch}');

    for (final phase in ['settled', 'rapid']) {
      for (final target in [12, 25, 36, 7, 30, 18]) {
        final start = DateTime.now().microsecondsSinceEpoch;
        print('PROFILE_JUMP_START phase=$phase page=$target at_us=$start '
            'rss=${ProcessInfo.currentRss}');
        await controller.goToPage(
          pageNumber: target,
          anchor: PdfPageAnchor.top,
          duration: Duration.zero,
        );
        for (var i = 0; i < (phase == 'rapid' ? 12 : 75); i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        print('PROFILE_JUMP_SETTLED phase=$phase page=$target '
            'at_us=${DateTime.now().microsecondsSinceEpoch} '
            'rss=${ProcessInfo.currentRss} retained=${budget.retainedBytes} '
            'pending=${budget.pendingBytes}');
        expect(controller.pageNumber, target);
        expect(tester.takeException(), isNull);
      }
    }
    print('PROFILE_JUMP_PEAK estimated=${budget.peakEstimatedBytes} '
        'budget=${budget.maximumBytes} rss=${ProcessInfo.currentRss} '
        'max_rss=${ProcessInfo.maxRss}');
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });
}
