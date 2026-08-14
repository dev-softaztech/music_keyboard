class SheetFormatConfig {
  final double musicSheetWidth;

  final double a4Height;

  final double a4ProportionalRatio;

  final int rowsOnFirstPage;

  final int rowsOnFollowingPages;

  const SheetFormatConfig({
    required this.musicSheetWidth,
    required this.a4Height,
    required this.a4ProportionalRatio,
    required this.rowsOnFirstPage,
    required this.rowsOnFollowingPages,
  });

  double get a4ProportionalHeight => musicSheetWidth * a4ProportionalRatio;
}
