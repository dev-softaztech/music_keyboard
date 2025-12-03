import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:screenshot/screenshot.dart';

class PdfExporter {
  static const double a4Width = 595.28; //595.28
  static const double a4Height = 1700; //841.89
  static const double pageMargin = 50.0;
  static const double availableHeight = a4Height - (2 * pageMargin);

  static const double titleComposerSpace = 50.0;
  static const double lineSpacing = 10.0;
  static const double rowHeight = lineSpacing * 4;

  static Future<void> exportMultiPageToPdf({
    required List<SheetRows> sheetRows,
    required double rowSpacing,
    required String title,
    required String composer,
    required ScreenshotController screenshotController,
    required Function(int startRow, int endRow, bool showTitle)
        updateSheetForCapture,
    required Function() captureScreenshot,
  }) async {
    final pageBreaks = calculatePageBreaks(sheetRows, rowSpacing);

    final pdf = pw.Document();

    for (int pageIndex = 0; pageIndex < pageBreaks.length; pageIndex++) {
      final pageInfo = pageBreaks[pageIndex];
      final bool isFirstPage = pageIndex == 0;

      // Update the sheet to show only the rows for this page
      updateSheetForCapture(pageInfo.startRow, pageInfo.endRow, isFirstPage);

      // Small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 200));

      // Capture screenshot for this page
      final imageBytes = await captureScreenshot();
      final image = pw.MemoryImage(imageBytes);

      // Add page to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Align(
              alignment: pw.Alignment.topCenter,
              child: pw.Container(
                //margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.fitWidth,
                ),
              ),
            );
          },
        ),
      );
    }

    // Reset to show all rows
    updateSheetForCapture(0, sheetRows.length - 1, true);

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'music_sheet_multipage.pdf');
  }

  /// Calculate how many rows can fit on a page
  static int calculateRowsPerPage(double rowSpacing, bool isFirstPage) {
    double usableHeight = availableHeight;
    if (isFirstPage) {
      usableHeight -= titleComposerSpace;
    }

    double rowTotalHeight = rowSpacing + rowHeight;
    return (usableHeight / rowTotalHeight)
        .floor()
        .clamp(1, 999); // At least 1 row per page
  }

  /// Calculate page breaks for the sheet
  static List<PageInfo> calculatePageBreaks(
      List<SheetRows> sheetRows, double rowSpacing) {
    final List<PageInfo> pageBreaks = [];
    int currentRow = 0;

    while (currentRow < sheetRows.length) {
      final bool isFirstPage = pageBreaks.isEmpty;
      final int rowsPerPage = calculateRowsPerPage(rowSpacing, isFirstPage);
      final int endRow =
          (currentRow + rowsPerPage - 1).clamp(0, sheetRows.length - 1);

      pageBreaks.add(PageInfo(
        startRow: currentRow,
        endRow: endRow,
        isFirstPage: isFirstPage,
      ));

      currentRow = endRow + 1;
    }

    return pageBreaks;
  }
}

class PageInfo {
  final int startRow;
  final int endRow;
  final bool isFirstPage;

  PageInfo({
    required this.startRow,
    required this.endRow,
    required this.isFirstPage,
  });
}
