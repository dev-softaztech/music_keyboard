/// Configuration for different sheet music formats
/// Defines layout properties for fitting sheet music to A4 PDF export
class SheetFormatConfig {
  /// Width of the music sheet canvas in pixels
  final double musicSheetWidth;

  /// Height of an A4 page in the coordinate system used by the app
  final double a4Height;

  /// The aspect ratio multiplier to calculate proportional height
  /// (used to maintain A4 proportions: width * a4ProportionalRatio = height)
  final double a4ProportionalRatio;

  /// Number of staff rows that fit on the first page (with title)
  final int rowsOnFirstPage;

  /// Number of staff rows that fit on subsequent pages (without title)
  final int rowsOnFollowingPages;

  const SheetFormatConfig({
    required this.musicSheetWidth,
    required this.a4Height,
    required this.a4ProportionalRatio,
    required this.rowsOnFirstPage,
    required this.rowsOnFollowingPages,
  });

  /// Calculate the proportional height based on width and ratio
  double get a4ProportionalHeight => musicSheetWidth * a4ProportionalRatio;
}
