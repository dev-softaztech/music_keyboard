(List<double> sharpPositions, List<double> flatPositions)
    getPositionsForClefType(
        String clefType, double staffTop, double lineSpacing) {
  List<double> sharpPositions = [];
  List<double> flatPositions = [];
  if (clefType == 'Treble') {
    sharpPositions = [
      staffTop + (lineSpacing * 0.1), // F# (4th line)
      staffTop + (lineSpacing * 1.4), // C# (3rd line)
      staffTop + (lineSpacing * -0.5), // G# (above staff)
      staffTop + (lineSpacing * 0.9), // D# (4th space)
      staffTop + (lineSpacing * 2.5), // A# (2nd line)
      staffTop + (lineSpacing * 0.4), // E# (4th line)
      staffTop + (lineSpacing * 2), // B# (3rd line)
    ];

    flatPositions = [
      staffTop + (lineSpacing * 2.0), // Bb (3rd line)
      staffTop + (lineSpacing * 0.5), // Eb (4th space)
      staffTop + (lineSpacing * 2.6), // Ab (2nd line)
      staffTop + (lineSpacing * 1.0), // Db (3rd space)
      staffTop + (lineSpacing * 3.0), // Gb (3rd line)
      staffTop + (lineSpacing * 1.6), // Cb (4th space)
      staffTop + (lineSpacing * 3.5), // Fb (2nd line)
    ];
  } else if (clefType == 'Bass') {
    sharpPositions = [
      staffTop + (lineSpacing * 1.0), // F# (4th line)
      staffTop + (lineSpacing * 2.3), // C# (3rd line)
      staffTop + (lineSpacing * 0.4), // G# (above staff)
      staffTop + (lineSpacing * 1.8), // D# (4th space)
      staffTop + (lineSpacing * 3.4), // A# (2nd line)
      staffTop + (lineSpacing * 1.4), // E# (4th line)
      staffTop + (lineSpacing * 3.0), // B# (3rd line)
    ];

    flatPositions = [
      staffTop + (lineSpacing * 3.0), // Bb (3rd line)
      staffTop + (lineSpacing * 1.5), // Eb (4th space)
      staffTop + (lineSpacing * 3.6), // Ab (2nd line)
      staffTop + (lineSpacing * 2.0), // Db (3rd space)
      staffTop + (lineSpacing * 4.0), // Gb (3rd line)
      staffTop + (lineSpacing * 2.6), // Cb (4th space)
      staffTop + (lineSpacing * 4.5), // Fb (2nd line)
    ];
  } else if (clefType == 'Alto') {
    sharpPositions = [
      staffTop + (lineSpacing * 0.5), // F# (4th line)
      staffTop + (lineSpacing * 2.1), // C# (3rd line)
      staffTop + (lineSpacing * 0.1), // G# (above staff)
      staffTop + (lineSpacing * 1.4), // D# (4th space)
      staffTop + (lineSpacing * 3.0), // A# (2nd line)
      staffTop + (lineSpacing * 1.1), // E# (4th line)
      staffTop + (lineSpacing * 2.5), // B# (3rd line)
    ];

    flatPositions = [
      staffTop + (lineSpacing * 2.5), // Bb (3rd line)
      staffTop + (lineSpacing * 1.0), // Eb (4th space)
      staffTop + (lineSpacing * 3.1), // Ab (2nd line)
      staffTop + (lineSpacing * 1.5), // Db (3rd space)
      staffTop + (lineSpacing * 3.5), // Gb (3rd line)
      staffTop + (lineSpacing * 2.1), // Cb (4th space)
      staffTop + (lineSpacing * 4.0), // Fb (2nd line)
    ];
  } else if (clefType == 'Tenor') {
    sharpPositions = [
      staffTop + (lineSpacing * 3), // F# (4th line)
      staffTop + (lineSpacing * 1.1), // C# (3rd line)
      staffTop + (lineSpacing * 2.5), // G# (above staff)
      staffTop + (lineSpacing * 0.5), // D# (4th space)
      staffTop + (lineSpacing * 2.1), // A# (2nd line)
      staffTop + (lineSpacing * 0.1), // E# (4th line)
      staffTop + (lineSpacing * 1.6), // B# (3rd line)
    ];

    flatPositions = [
      staffTop + (lineSpacing * 1.5), // Bb (3rd line)
      staffTop + (lineSpacing * 0.0), // Eb (4th space)
      staffTop + (lineSpacing * 2.0), // Ab (2nd line)
      staffTop + (lineSpacing * 0.5), // Db (3rd space)
      staffTop + (lineSpacing * 2.5), // Gb (3rd line)
      staffTop + (lineSpacing * 1), // Cb (4th space)
      staffTop + (lineSpacing * 3), // Fb (2nd line)
    ];
  }
  return (sharpPositions, flatPositions);
}
