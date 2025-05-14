import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vec;
import 'dart:math' as math;
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';

class MusicSheetPainter extends CustomPainter {
  final List<List<MusicalNote>> sheetNoteRows;
  final int selectedRow;
  final int selectedIndex;
  final bool showCursor;
  final List<int> rowSpacingList;

  MusicSheetPainter(this.sheetNoteRows, this.selectedRow, this.selectedIndex,
      this.showCursor, this.rowSpacingList);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    Paint paint = Paint()..color = Colors.black;
    Color noteColour = Colors.black;
    const double lineSpacing = 10;
    const double sheetHeight = lineSpacing * 4;
    const double rowSpacing = 130.0;

    for (int rowIndex = 0; rowIndex < sheetNoteRows.length; rowIndex++) {
      double staffTop = rowIndex == 0
          ? rowSpacing / 2
          : (rowIndex * rowSpacing) +
              (rowIndex * sheetHeight) +
              (rowSpacing / 2);
      drawStaffLines(canvas, paint, staffTop, lineSpacing, sheetHeight, size);

      double x = 25.0;
      int currentRowSpacing = rowSpacingList[rowIndex];

      // Set duration values for notes in this row
      BarLineCalculator.setNoteDurations(sheetNoteRows[rowIndex]);

      // Find the applicable time signature for this row
      String? timeSignature;

      // First check for time signatures within the current row
      timeSignature =
          BarLineCalculator.findLastTimeSignature(sheetNoteRows[rowIndex]);

      // If no time signature found in current row, check previous rows
      if (timeSignature == null && rowIndex > 0) {
        timeSignature = BarLineCalculator.findLastTimeSignatureAcrossRows(
            sheetNoteRows, rowIndex - 1);
      }

      // Track bars and their properties for warning display
      List<
          ({
            int startIndex,
            int endIndex,
            double xStart,
            double xEnd,
            bool isOverfilled
          })> bars = [];
      int barStartIndex = 0;
      double barStartX = 25.0;
      double currentBarDuration = 0.0;
      String? currentBarTimeSignature = timeSignature;

      // First pass: identify all bars and their properties
      for (int i = 0; i < sheetNoteRows[rowIndex].length; i++) {
        MusicalNote note = sheetNoteRows[rowIndex][i];
        double currentX = barStartX + ((i - barStartIndex) * currentRowSpacing);

        // Check for time signature changes within the row
        if (note.type == NoteType.clef &&
            BarLineCalculator.timeSignatureValues
                .containsKey(note.unicodeCharacter)) {
          currentBarTimeSignature = note.unicodeCharacter;

          // End the previous bar if there was one
          if (i > 0) {
            bool isOverfilled = (currentBarTimeSignature != null &&
                    currentBarTimeSignature != "") &&
                BarLineCalculator.hasBarTooManyNotes(
                    currentBarDuration, currentBarTimeSignature);

            bars.add((
              startIndex: barStartIndex,
              endIndex: i - 1,
              xStart: barStartX,
              xEnd: currentX - currentRowSpacing,
              isOverfilled: isOverfilled
            ));
          }

          barStartIndex = i + 1;
          barStartX = currentX + getNoteWidth(note);
          currentBarDuration = 0.0;
          // Removed the continue statement that was causing time signatures to be invisible
        }

        // Check if this is a bar line (either existing or to be added)
        if (note.type == NoteType.bar) {
          // End the current bar
          bool isOverfilled = currentBarTimeSignature != null &&
              BarLineCalculator.hasBarTooManyNotes(
                  currentBarDuration, currentBarTimeSignature);

          bars.add((
            startIndex: barStartIndex,
            endIndex: i - 1,
            xStart: barStartX,
            xEnd: currentX - currentRowSpacing,
            isOverfilled: isOverfilled
          ));

          barStartIndex = i + 1;
          barStartX = currentX + currentRowSpacing;
          currentBarDuration = 0.0;
        } else {
          currentBarDuration += note.duration;
        }
      }

      // Add the final bar if there are notes after the last bar line
      if (barStartIndex < sheetNoteRows[rowIndex].length) {
        double endX =
            25.0 + (sheetNoteRows[rowIndex].length * currentRowSpacing);
        bool isOverfilled = currentBarTimeSignature != null &&
            BarLineCalculator.hasBarTooManyNotes(
                currentBarDuration, currentBarTimeSignature);

        bars.add((
          startIndex: barStartIndex,
          endIndex: sheetNoteRows[rowIndex].length - 1,
          xStart: barStartX,
          xEnd: endX,
          isOverfilled: isOverfilled
        ));
      }

      // Second pass: draw all notes
      x = 25.0; // Reset x position for drawing
      for (int i = 0; i < sheetNoteRows[rowIndex].length; i++) {
        MusicalNote note = sheetNoteRows[rowIndex][i];

        if (rowIndex == selectedRow && i == selectedIndex) {
          paint = Paint()..color = const Color.fromARGB(255, 222, 15, 0);
          noteColour = const Color.fromARGB(255, 222, 15, 0);
        } else {
          paint = Paint()..color = Colors.black;
          noteColour = Colors.black;
        }

        drawNote(canvas, paint, note, lineSpacing, staffTop, x,
            sheetNoteRows[rowIndex], i, currentRowSpacing, noteColour);

        var staffCenter = staffTop + (lineSpacing * 2);

        if (note.isTiedToNext && i < sheetNoteRows[rowIndex].length - 1) {
          double y = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);
          drawTie(canvas, paint, x, staffCenter, x + currentRowSpacing, y);
        }

        if (note.slurEndIndex != null) {
          double startX = x;
          double startY = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);

          double endX = 25.0 + (note.slurEndIndex! * currentRowSpacing);
          double endY = calculateNoteYMainSheet(
              sheetNoteRows[rowIndex][note.slurEndIndex!].pitch,
              sheetNoteRows[rowIndex][note.slurEndIndex!].octave,
              lineSpacing,
              staffTop);

          drawSlurBetweenNotes(
              canvas,
              paint,
              startX,
              startY,
              endX,
              endY,
              staffCenter,
              i,
              note.slurEndIndex!,
              noteColour,
              sheetNoteRows[rowIndex]);
        }

        x +=
            note.type == NoteType.clef ? getNoteWidth(note) : currentRowSpacing;
      }

      // We no longer add automatic bar lines here as it's now handled in CurrentSelectedNoteProvider

      if (rowIndex == selectedRow) {
        int clefCount = sheetNoteRows[rowIndex]
            .where((x) => x.type == NoteType.clef)
            .length;

        // Draw the cursor if showCursor is true
        if (showCursor) {
          drawInsertionCursor(
              canvas,
              paint,
              staffTop,
              selectedIndex,
              size,
              currentRowSpacing,
              clefCount,
              sheetNoteRows[rowIndex],
              lineSpacing);
        }

        // Find which bar contains the selected note and check if it's overfilled
        for (var bar in bars) {
          if (selectedIndex >= bar.startIndex &&
              selectedIndex <= bar.endIndex &&
              bar.isOverfilled) {
            // Draw warning above the specific bar
            drawTooManyNotesWarning(canvas, staffTop, bar.xStart, bar.xEnd);
            break;
          }
        }
      }

      paint = Paint()..color = Colors.black;
      noteColour = Colors.black;
    }
  }

  /// Draw a warning when there are too many notes in a bar
  void drawTooManyNotesWarning(
      Canvas canvas, double staffTop, double barStartX, double barEndX) {
    final TextPainter textPainter = TextPainter(
      text: const TextSpan(
        text: 'Too many notes for bar',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Position the warning above the specific bar
    final double barWidth = barEndX - barStartX;
    final double x = barStartX + (barWidth - textPainter.width) / 2;
    final double y = staffTop - 30;

    // Draw a semi-transparent background for better readability
    final Rect backgroundRect = Rect.fromLTWH(
        x - 10, y - 5, textPainter.width + 20, textPainter.height + 10);

    canvas.drawRect(
      backgroundRect,
      Paint()..color = Colors.white.withOpacity(0.8),
    );

    // Draw the warning text
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  void drawStaffLines(Canvas canvas, Paint paint, double staffTop,
      double lineSpacing, double sheetHeight, Size size) {
    for (int i = 0; i < 5; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(
        Offset(5, y),
        Offset(size.width - 5, y),
        paint..strokeWidth = 1.0,
      );
    }

    canvas.drawLine(Offset(5, staffTop), Offset(5, staffTop + (sheetHeight)),
        paint..strokeWidth = 1.0);
    canvas.drawLine(
        Offset(size.width - 5, staffTop),
        Offset(size.width - 5, staffTop + (sheetHeight)),
        paint..strokeWidth = 1.0);
  }

  void drawInsertionCursor(
      Canvas canvas,
      Paint paint,
      double staffTop,
      int index,
      Size size,
      int rowSpacing,
      int clefCount,
      List<MusicalNote> notes,
      double lineSpacing) {
    // Calculate cursor X position using the new note width calculator
    double cursorX = notes.isEmpty
        ? 25.0
        : calculateXPositionForIndex(index, notes, rowSpacing);

    double cursorY = staffTop + (lineSpacing * 2);

    final Paint cursorPaint = Paint()..color = Colors.blue.withOpacity(0.8);

    canvas.drawLine(
      Offset(cursorX, cursorY - 60),
      Offset(cursorX, cursorY + 60),
      cursorPaint..strokeWidth = 3.5,
    );
  }

  void drawTie(Canvas canvas, Paint paint, double startX, double staffCentre,
      double endX, double y) {
    Path path = Path();
    double controlY = y >= staffCentre ? y + 30 : y - 30;
    y = y >= staffCentre ? y + 10 : y - 10;

    path.moveTo(startX + 5, y);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX - 5, y);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }

  void drawSlur(Canvas canvas, Paint paint, double startX, double startY,
      double endX, double endY, double staffCentre) {
    Path path = Path();
    //pass in start index and end index so I can work out how large to make the curve.

    double controlY = (startY < endY) ? startY - 40 : startY + 40;
    startY = startY >= staffCentre ? startY + 10 : startY - 10;
    endY = startY >= staffCentre ? endY + 10 : endY - 10;

    path.moveTo(startX + 5, startY);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX - 5, endY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }

  void drawSlurBetweenNotes(
    Canvas canvas,
    Paint paint,
    double startX,
    double startY,
    double endX,
    double endY,
    double staffCentre,
    int startIndex,
    int endIndex,
    Color color,
    List<MusicalNote> rowNotes,
  ) {
    // Ensure left-to-right direction
    final int minIndex = startIndex < endIndex ? startIndex : endIndex;
    final int maxIndex = startIndex > endIndex ? startIndex : endIndex;

    // Determine if the slur should be above or below based on note positions
    // If most notes are above the staff center, slur should be below, and vice versa
    int notesAboveCenter = 0;
    int notesBelowCenter = 0;

    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];
      if (note.noteY > staffCentre) {
        notesAboveCenter++;
      } else {
        notesBelowCenter++;
      }
    }

    final bool isSlurAbove = notesBelowCenter >= notesAboveCenter;

    // Apply vertical offset based on slur position - increase for better clearance
    startY = isSlurAbove ? startY - 12 : startY + 12;
    endY = isSlurAbove ? endY - 12 : endY + 12;

    final Offset start = Offset(startX, startY);
    final Offset end = Offset(endX, endY);

    // Start with a moderate base curve height
    double curveHeight = 30;
    double yDifference = endY - startY;
    int noteSpan = (maxIndex - minIndex).clamp(1, rowNotes.length);
    double stepY = yDifference / noteSpan;
    double horizontalDistance = (endX - startX).abs();

    // Define note head size (approximate)
    const double noteHeadHeight = 10.0;
    const double noteHeadWidth = 12.0;

    // Track obstacles for optimal control point placement
    List<
        ({
          double x,
          double y,
          double width,
          double height,
          bool isUpsideDown,
          bool isStem,
          double obstacleTop,
          double obstacleBottom
        })> obstacles = [];

    bool hasUpsideDownStems = false;
    bool hasDownwardStems = false;

    // First pass: identify all obstacles (note heads and stems)
    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];

      // Calculate note X position more accurately
      double noteX = startX + ((i - minIndex) / noteSpan) * horizontalDistance;

      // Add note head as an obstacle (all notes have heads)
      double noteHeadTop = note.noteY - (noteHeadHeight / 2);
      double noteHeadBottom = note.noteY + (noteHeadHeight / 2);

      obstacles.add((
        x: noteX,
        y: note.noteY,
        width: noteHeadWidth,
        height: noteHeadHeight,
        isUpsideDown: false,
        isStem: false,
        obstacleTop: noteHeadTop,
        obstacleBottom: noteHeadBottom
      ));

      // Skip stem calculation for notes that don't have stems
      if (note.type == NoteType.whole ||
          note.type == NoteType.rest ||
          note.type == NoteType.clef ||
          note.type == NoteType.bar ||
          note.type == NoteType.accidental) {
        continue;
      }

      // Determine if the note's stem is upside down (pointing up)
      final bool isUpsideDownNote = note.noteY < staffCentre;

      if (isUpsideDownNote) {
        hasUpsideDownStems = true;
      } else {
        hasDownwardStems = true;
      }

      // Calculate stem height based on note type and connected status
      double stemHeight = 35.0; // Base stem height

      // Adjust stem height for 32nd or 64th notes
      if (note.type == NoteType.thirtySecond ||
          note.type == NoteType.sixtyFourth) {
        stemHeight += 10.0;
      }

      // For connected notes, calculate more accurate stem height
      if ((note.type == NoteType.eighth ||
              note.type == NoteType.sixteenth ||
              note.type == NoteType.thirtySecond ||
              note.type == NoteType.sixtyFourth) &&
          note.isConnected) {
        // Get the connected notes group to determine actual stem height
        var notesGroup = getConnectedNotesGroup(i, rowNotes);
        var connectedNotesGroup = notesGroup.notesGroup;
        bool firstNoteUpsideDown = false;

        if (connectedNotesGroup.isNotEmpty) {
          var notesGroupYs = getConnectedNotesGroupHighestY(connectedNotesGroup,
              10.0, staffCentre); // Using lineSpacing = 10.0

          double connectedGroupHighestY = notesGroupYs.highestY;
          double connectedGroupLowestY = notesGroupYs.lowestY;
          firstNoteUpsideDown = notesGroupYs.firstNoteY < staffCentre;

          // Adjust stem height based on the connected group
          if (!firstNoteUpsideDown) {
            stemHeight = (note.noteY - connectedGroupHighestY) + stemHeight;
          } else {
            stemHeight = (connectedGroupLowestY - note.noteY) + stemHeight;
          }

          // Add buffer for complex connected notes
          if (notesGroupYs.doesGroupContain32ndOr64thNote) {
            stemHeight += 10.0;
          }
        }
      }

      // Add a safety buffer to stem height
      stemHeight += 10.0;

      // Calculate stem position and dimensions
      double stemX = isUpsideDownNote ? noteX - 5.0 : noteX + 5.0;
      double stemWidth = 1.5; // Stem width
      double stemTop, stemBottom;

      if (isUpsideDownNote) {
        // Stem points up
        stemTop = note.noteY - stemHeight;
        stemBottom = note.noteY;
      } else {
        // Stem points down
        stemTop = note.noteY;
        stemBottom = note.noteY + stemHeight;
      }

      // Add stem as an obstacle
      obstacles.add((
        x: stemX,
        y: note.noteY,
        width: stemWidth,
        height: stemHeight,
        isUpsideDown: isUpsideDownNote,
        isStem: true,
        obstacleTop: stemTop,
        obstacleBottom: stemBottom
      ));
    }

    // Find the most problematic obstacle
    double maxObstacleImpact = 0;
    double obstaclePositionRatio = 0.5; // Default to center

    for (var obstacle in obstacles) {
      // Calculate where this obstacle is along the x-axis (0.0 = start, 1.0 = end)
      double positionRatio = (obstacle.x - startX) / horizontalDistance;
      positionRatio = positionRatio.clamp(0.0, 1.0);

      // Calculate the impact of this obstacle
      double impact = 0;

      if (obstacle.isStem) {
        // Stems have higher impact
        if (isSlurAbove && obstacle.isUpsideDown) {
          // For upward stems when slur is above
          impact = obstacle.height * 1.5;
        } else if (!isSlurAbove && !obstacle.isUpsideDown) {
          // For downward stems when slur is below
          impact = obstacle.height * 1.5;
        }
      } else {
        // Note heads have impact regardless of slur position
        impact = obstacle.height;
      }

      // If this obstacle has more impact than previous ones
      if (impact > maxObstacleImpact) {
        maxObstacleImpact = impact;
        // Shift control point slightly away from the obstacle
        obstaclePositionRatio =
            positionRatio > 0.5 ? positionRatio - 0.2 : positionRatio + 0.2;
        obstaclePositionRatio = obstaclePositionRatio.clamp(
            0.3, 0.7); // Keep within reasonable bounds
      }
    }

    // Calculate the Bezier curve path to check for intersections
    List<Offset> bezierPoints = [];
    const int segments = 100;

    // Calculate control point for the Bezier curve
    double controlX = startX + (horizontalDistance * obstaclePositionRatio);
    double controlY = (start.dy + end.dy) / 2;

    // Apply initial curve height
    double heightMultiplier = 1.0 + (horizontalDistance / 500);
    heightMultiplier = heightMultiplier.clamp(1.0, 1.5);

    controlY += isSlurAbove
        ? -curveHeight * heightMultiplier
        : curveHeight * heightMultiplier;

    Offset control = Offset(controlX, controlY);

    // Generate points along the curve
    for (int i = 0; i <= segments; i++) {
      double t = i / segments;
      double x = (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * control.dx +
          t * t * end.dx;
      double y = (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * control.dy +
          t * t * end.dy;
      bezierPoints.add(Offset(x, y));
    }

    // Check for intersections with obstacles
    bool hasIntersection;
    int maxIterations = 10;
    int iteration = 0;

    do {
      hasIntersection = false;
      iteration++;

      // Check each obstacle against the curve
      for (var obstacle in obstacles) {
        // For stems, check if the curve intersects the stem line
        if (obstacle.isStem) {
          double stemX = obstacle.x;
          double stemTop = obstacle.obstacleTop;
          double stemBottom = obstacle.obstacleBottom;

          // Find the closest point on the curve to this stem's x-coordinate
          Offset? closestPoint;
          double minDistance = double.infinity;

          for (var point in bezierPoints) {
            double distance = (point.dx - stemX).abs();
            if (distance < minDistance) {
              minDistance = distance;
              closestPoint = point;
            }
          }

          if (closestPoint != null && minDistance < 5.0) {
            // Check if this point intersects with the stem
            bool intersects = false;

            if (isSlurAbove && obstacle.isUpsideDown) {
              // For upward stems when slur is above
              intersects =
                  closestPoint.dy > stemTop && closestPoint.dy < stemBottom;
            } else if (!isSlurAbove && !obstacle.isUpsideDown) {
              // For downward stems when slur is below
              intersects =
                  closestPoint.dy > stemTop && closestPoint.dy < stemBottom;
            }

            if (intersects) {
              hasIntersection = true;
              // Increase curve height to avoid this stem
              curveHeight += 10.0;
              break;
            }
          }
        }
        // For note heads, check if the curve passes through the note head
        else {
          double noteHeadLeft = obstacle.x - (obstacle.width / 2);
          double noteHeadRight = obstacle.x + (obstacle.width / 2);
          double noteHeadTop = obstacle.obstacleTop;
          double noteHeadBottom = obstacle.obstacleBottom;

          // Check if any point on the curve intersects with this note head
          for (var point in bezierPoints) {
            if (point.dx >= noteHeadLeft &&
                point.dx <= noteHeadRight &&
                point.dy >= noteHeadTop &&
                point.dy <= noteHeadBottom) {
              hasIntersection = true;
              // Increase curve height to avoid this note head
              curveHeight += 8.0;
              break;
            }
          }

          if (hasIntersection) break;
        }
      }

      if (hasIntersection) {
        // Recalculate control point with new curve height
        controlY = (start.dy + end.dy) / 2;
        controlY += isSlurAbove
            ? -curveHeight * heightMultiplier
            : curveHeight * heightMultiplier;
        control = Offset(controlX, controlY);

        // Regenerate bezier points
        bezierPoints.clear();
        for (int i = 0; i <= segments; i++) {
          double t = i / segments;
          double x = (1 - t) * (1 - t) * start.dx +
              2 * (1 - t) * t * control.dx +
              t * t * end.dx;
          double y = (1 - t) * (1 - t) * start.dy +
              2 * (1 - t) * t * control.dy +
              t * t * end.dy;
          bezierPoints.add(Offset(x, y));
        }
      }
    } while (hasIntersection && iteration < maxIterations);

    // Add moderate extra height if we have stems in the way
    if (hasUpsideDownStems && isSlurAbove) {
      curveHeight += 15;
    }
    if (hasDownwardStems && !isSlurAbove) {
      curveHeight += 10;
    }

    // Limit maximum curve height to prevent overlapping with other staves
    // The maximum is now proportional to the horizontal distance
    double maxHeight = math.min(80, horizontalDistance * 0.3);
    curveHeight = curveHeight.clamp(30, maxHeight);

    // Final control point calculation
    controlY = (start.dy + end.dy) / 2;
    controlY += isSlurAbove
        ? -curveHeight * heightMultiplier
        : curveHeight * heightMultiplier;
    control = Offset(controlX, controlY);

    // Draw the slur
    drawVariableThicknessBezier(
      canvas: canvas,
      start: start,
      control: control,
      end: end,
      maxThickness: 3,
      color: color,
    );
  }

  void drawVariableThicknessBezier({
    required Canvas canvas,
    required Offset start,
    required Offset control,
    required Offset end,
    required double maxThickness,
    required Color color,
  }) {
    const int segments = 300; // More segments = smoother curve
    final path = Path();

    // Store left and right edge of the stroke
    List<Offset> leftPoints = [];
    List<Offset> rightPoints = [];

    for (int i = 0; i <= segments; i++) {
      double t = i / segments;

      // Bézier curve formula
      double x = (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * control.dx +
          t * t * end.dx;
      double y = (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * control.dy +
          t * t * end.dy;
      Offset point = Offset(x, y);

      // Tangent vector
      double dx =
          2 * (1 - t) * (control.dx - start.dx) + 2 * t * (end.dx - control.dx);
      double dy =
          2 * (1 - t) * (control.dy - start.dy) + 2 * t * (end.dy - control.dy);
      vec.Vector2 tangent = vec.Vector2(dx, dy).normalized();

      // Normal vector (perpendicular to tangent)
      vec.Vector2 normal = vec.Vector2(-tangent.y, tangent.x);

      // Thickness tapers in and out toward center
      double thickness =
          maxThickness * (1 - ((t - 0.5) * 2).abs()); // triangle shape taper

      vec.Vector2 offset = normal.scaled(thickness / 2);
      Offset left = point + Offset(offset.x, offset.y);
      Offset right = point - Offset(offset.x, offset.y);

      leftPoints.add(left);
      rightPoints.add(right);
    }

    // Draw thick curve as a filled path
    path.addPolygon(leftPoints, false);
    path.addPolygon(rightPoints.reversed.toList(), true); // Close the shape

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..strokeWidth = 1.0,
    );
  }
}
