import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vec;
import 'dart:math' as math;
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

class ExpressionMarkingsPainter {
  void drawTie(Canvas canvas, Paint paint, double startX, double staffCentre,
      double endX, double y) {
    Path path = Path();
    double controlY = y >= staffCentre ? y + 25 : y - 25;
    y = y >= staffCentre ? y + 5 : y - 5;

    path.moveTo(startX + 6, y);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX - 6, y);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }

  void drawSlur(Canvas canvas, Paint paint, double startX, double startY,
      double endX, double endY, double staffCentre) {
    Path path = Path();

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
      double staffTop,
      double staffCentre,
      int startIndex,
      int endIndex,
      Color color,
      List<MusicalNote> rowNotes,
      int spaceNotesCount) {
    // Ensure left-to-right direction
    final int minIndex = startIndex < endIndex ? startIndex : endIndex;
    final int maxIndex = startIndex > endIndex ? startIndex : endIndex;

    // Determine if the slur should be above or below based on note positions
    // If most notes are above the staff center, slur should be below, and vice versa
    int notesAboveCenter = 0;
    int notesBelowCenter = 0;

    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];
      if (note.type != NoteType.space) {
        if (note.noteY > staffCentre) {
          notesAboveCenter++;
        } else {
          notesBelowCenter++;
        }
      }
    }

    final bool isSlurAbove = notesBelowCenter >= notesAboveCenter;

    startY = isSlurAbove ? startY - 12 : startY + 12;
    endY = isSlurAbove ? endY - 12 : endY + 12;

    final Offset start = Offset(startX, startY);
    final Offset end = Offset(endX, endY);

    //Base curve height
    double curveHeight = 30;

    int noteSpan = ((maxIndex - minIndex) - spaceNotesCount)
        .clamp(1, rowNotes.length - spaceNotesCount);
    double horizontalDistance = (endX - startX).abs();

    const double noteHeadHeight = 10.0;
    const double noteHeadWidth = 12.0;

    // Track obstacles for optimal control point placement
    List<
        ({
          double x,
          double y,
          double width,
          double height,
          bool? isUpsideDown,
          bool isStem,
          double obstacleTop,
          double obstacleBottom
        })> obstacles = [];

    bool hasUpsideDownStems = false;
    bool hasDownwardStems = false;

    // Find the extreme Y positions of all intermediate notes to ensure proper clearance
    double highestNoteY = double.infinity;
    double lowestNoteY = double.negativeInfinity;
    double highestStemY = double.infinity;
    double lowestStemY = double.negativeInfinity;

    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];
      if (note.type != NoteType.space) {
        var spaceCount = 0;

        for (int index = minIndex; index <= i; index++) {
          final noteCurrent = rowNotes[index];
          if (noteCurrent.type == NoteType.space) {
            spaceCount++;
          }
        }

        double noteX = startX +
            ((i - minIndex - spaceCount) / noteSpan) * horizontalDistance;

        highestNoteY = math.min(highestNoteY, note.noteY);
        lowestNoteY = math.max(lowestNoteY, note.noteY);

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

        if (note.type == NoteType.whole ||
            note.type == NoteType.rest ||
            note.type == NoteType.clef ||
            note.type == NoteType.bar ||
            note.type == NoteType.accidental ||
            note.type == NoteType.timeSignature ||
            note.type == NoteType.keySignature ||
            note.type == NoteType.accidental ||
            note.type == NoteType.space) {
          continue;
        }

        if (note.isUpsideDown == true) {
          hasUpsideDownStems = true;
        } else {
          hasDownwardStems = true;
        }

        double stemHeight = 35.0; // Base stem height

        if (note.type == NoteType.thirtySecond ||
            note.type == NoteType.sixtyFourth) {
          stemHeight += 10.0;
        }

        if ((note.type == NoteType.eighth ||
                note.type == NoteType.sixteenth ||
                note.type == NoteType.thirtySecond ||
                note.type == NoteType.sixtyFourth) &&
            note.isBeamed) {
          var notesGroup = getBeamedNotesGroup(i, rowNotes);
          var connectedNotesGroup = notesGroup.notesGroup;
          bool firstNoteUpsideDown = false;

          if (connectedNotesGroup.isNotEmpty) {
            var notesGroupYs = getBeamedNotesGroupHighestY(
                connectedNotesGroup, 10.0, staffTop, staffCentre);

            double connectedGroupHighestY = notesGroupYs.highestY;
            double connectedGroupLowestY = notesGroupYs.lowestY;
            firstNoteUpsideDown = notesGroupYs.firstNoteY < staffCentre;

            if (!firstNoteUpsideDown) {
              stemHeight = (note.noteY - connectedGroupHighestY) + stemHeight;
            } else {
              stemHeight = (connectedGroupLowestY - note.noteY) + stemHeight;
            }

            if (notesGroupYs.doesGroupContain32ndOr64thNote) {
              stemHeight += 30.0;
            }
          }
        }

        stemHeight += 30.0;

        double stemX = note.isUpsideDown == true ? noteX - 5.0 : noteX + 5.0;
        double stemWidth = 1.5;
        double stemTop, stemBottom;

        if (note.isUpsideDown == true) {
          stemTop = note.noteY - stemHeight;
          stemBottom = note.noteY;

          highestStemY = math.min(highestStemY, stemTop);
        } else {
          stemTop = note.noteY;
          stemBottom = note.noteY + stemHeight;
          lowestStemY = math.max(lowestStemY, stemBottom);
        }

        obstacles.add((
          x: stemX,
          y: note.noteY,
          width: stemWidth,
          height: stemHeight,
          isUpsideDown: note.isUpsideDown,
          isStem: true,
          obstacleTop: stemTop,
          obstacleBottom: stemBottom
        ));
      }
    }

    double minRequiredCurveHeight = 60.0;

    if (isSlurAbove) {
      double highestPoint = highestNoteY;
      if (highestStemY != double.infinity) {
        highestPoint = math.min(highestPoint, highestStemY);
      }

      double requiredControlY = highestPoint - 40.0;
      double slurMidY = (start.dy + end.dy) / 2;

      minRequiredCurveHeight =
          math.max(minRequiredCurveHeight, slurMidY - requiredControlY);

      if (hasUpsideDownStems) {
        minRequiredCurveHeight += 20.0;
      }
    } else {
      double lowestPoint = lowestNoteY;
      if (lowestStemY != double.negativeInfinity) {
        lowestPoint = math.max(lowestPoint, lowestStemY);
      }

      double requiredControlY = lowestPoint + 40.0;
      double slurMidY = (start.dy + end.dy) / 2;

      minRequiredCurveHeight =
          math.max(minRequiredCurveHeight, requiredControlY - slurMidY);

      if (hasDownwardStems) {
        minRequiredCurveHeight += 20.0;
      }
    }

    curveHeight = math.max(curveHeight, minRequiredCurveHeight);

    double maxObstacleImpact = 0;
    double obstaclePositionRatio = 0.5;

    for (var obstacle in obstacles) {
      double positionRatio = (obstacle.x - startX) / horizontalDistance;
      positionRatio = positionRatio.clamp(0.0, 1.0);

      double impact = 0;

      if (obstacle.isStem) {
        if (isSlurAbove && obstacle.isUpsideDown == true) {
          impact = obstacle.height * 1.5;
        } else if (!isSlurAbove && obstacle.isUpsideDown == false) {
          impact = obstacle.height * 1.5;
        }
      } else {
        impact = obstacle.height;
      }

      if (impact > maxObstacleImpact) {
        maxObstacleImpact = impact;
        obstaclePositionRatio =
            positionRatio > 0.5 ? positionRatio - 0.2 : positionRatio + 0.2;
        obstaclePositionRatio = obstaclePositionRatio.clamp(0.3, 0.7);
      }
    }

    double controlX = startX + (horizontalDistance * obstaclePositionRatio);
    double controlY = (start.dy + end.dy) / 2;

    double heightMultiplier = 1.0 + (horizontalDistance / 500);
    heightMultiplier = heightMultiplier.clamp(1.0, 1.5);

    controlY += isSlurAbove
        ? -curveHeight * heightMultiplier
        : curveHeight * heightMultiplier;

    const double minBufferSpace = 25.0;
    const double maxSlurHeight = 180.0;

    if (isSlurAbove) {
      double highestObstacle = highestNoteY;
      if (highestStemY != double.infinity) {
        highestObstacle = math.min(highestObstacle, highestStemY);
      }

      double forcedControlY = highestObstacle - minBufferSpace;
      controlY = math.min(controlY, forcedControlY);

      double maxAllowedY = staffCentre - maxSlurHeight;
      controlY = math.max(controlY, maxAllowedY);
    } else {
      double lowestObstacle = lowestNoteY;
      if (lowestStemY != double.negativeInfinity) {
        lowestObstacle = math.max(lowestObstacle, lowestStemY);
      }

      double forcedControlY = lowestObstacle + minBufferSpace;
      controlY = math.max(controlY, forcedControlY);

      double maxAllowedY = staffCentre + maxSlurHeight;
      controlY = math.min(controlY, maxAllowedY);
    }

    Offset control = Offset(controlX, controlY);

    List<Offset> bezierPoints = [];
    const int segments = 100;

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

    bool hasIntersection;
    int maxIterations = 5;
    int iteration = 0;

    do {
      hasIntersection = false;
      iteration++;

      for (var obstacle in obstacles) {
        if (obstacle.isStem) {
          double stemX = obstacle.x;
          double stemTop = obstacle.obstacleTop;
          double stemBottom = obstacle.obstacleBottom;

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
            bool intersects = false;

            if (isSlurAbove && obstacle.isUpsideDown == true) {
              intersects =
                  closestPoint.dy > stemTop && closestPoint.dy < stemBottom;
            } else if (!isSlurAbove && obstacle.isUpsideDown == false) {
              intersects =
                  closestPoint.dy > stemTop && closestPoint.dy < stemBottom;
            }

            if (intersects) {
              hasIntersection = true;
              curveHeight += 10.0;
              break;
            }
          }
        } else {
          double noteHeadLeft = obstacle.x - (obstacle.width / 2);
          double noteHeadRight = obstacle.x + (obstacle.width / 2);
          double noteHeadTop = obstacle.obstacleTop;
          double noteHeadBottom = obstacle.obstacleBottom;

          for (var point in bezierPoints) {
            if (point.dx >= noteHeadLeft &&
                point.dx <= noteHeadRight &&
                point.dy >= noteHeadTop &&
                point.dy <= noteHeadBottom) {
              hasIntersection = true;
              curveHeight += 8.0;
              break;
            }
          }

          if (hasIntersection) break;
        }
      }

      if (hasIntersection) {
        controlY = (start.dy + end.dy) / 2;
        controlY += isSlurAbove
            ? -curveHeight * heightMultiplier
            : curveHeight * heightMultiplier;

        if (isSlurAbove) {
          double highestObstacle = highestNoteY;
          if (highestStemY != double.infinity) {
            highestObstacle = math.min(highestObstacle, highestStemY);
          }
          double forcedControlY = highestObstacle - minBufferSpace;
          controlY = math.min(controlY, forcedControlY);

          double maxAllowedY = staffCentre - maxSlurHeight;
          controlY = math.max(controlY, maxAllowedY);
        } else {
          double lowestObstacle = lowestNoteY;
          if (lowestStemY != double.negativeInfinity) {
            lowestObstacle = math.max(lowestObstacle, lowestStemY);
          }
          double forcedControlY = lowestObstacle + minBufferSpace;
          controlY = math.max(controlY, forcedControlY);

          double maxAllowedY = staffCentre + maxSlurHeight;
          controlY = math.min(controlY, maxAllowedY);
        }

        control = Offset(controlX, controlY);

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
    const int segments = 300;
    final path = Path();

    List<Offset> leftPoints = [];
    List<Offset> rightPoints = [];

    for (int i = 0; i <= segments; i++) {
      double t = i / segments;

      double x = (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * control.dx +
          t * t * end.dx;
      double y = (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * control.dy +
          t * t * end.dy;
      Offset point = Offset(x, y);

      double dx =
          2 * (1 - t) * (control.dx - start.dx) + 2 * t * (end.dx - control.dx);
      double dy =
          2 * (1 - t) * (control.dy - start.dy) + 2 * t * (end.dy - control.dy);
      vec.Vector2 tangent = vec.Vector2(dx, dy).normalized();

      vec.Vector2 normal = vec.Vector2(-tangent.y, tangent.x);

      double thickness = maxThickness * (1 - ((t - 0.5) * 2).abs());

      vec.Vector2 offset = normal.scaled(thickness / 2);
      Offset left = point + Offset(offset.x, offset.y);
      Offset right = point - Offset(offset.x, offset.y);

      leftPoints.add(left);
      rightPoints.add(right);
    }

    path.addPolygon(leftPoints, false);
    path.addPolygon(rightPoints.reversed.toList(), true);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..strokeWidth = 1.0,
    );
  }

  void drawDynamicCharacter(
      Canvas canvas,
      MusicalNote note,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 30,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: note.dynamicCharacter,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;

    if (note.noteY > lowestY) {
      lowestY = note.noteY;
    }
    if (note.isUpsideDown == true && note.noteY >= staffTop) {
      hasUpsideDownNoteOnStaff = true;
    }

    double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
    double minDynamicY = staffBottomLineY + 20;
    double yPos = math.max(lowestY + 50, minDynamicY);

    if (hasUpsideDownNoteOnStaff) {
      yPos += 30;
    }

    double xPos = x - (textPainter.width / 2);

    if (note.accentCharacter != "" && note.isUpsideDown == false) {
      yPos = yPos + 10;
    }

    textPainter.paint(canvas, Offset(xPos, yPos - 60));
  }

  void drawAccentCharacter(
      Canvas canvas,
      MusicalNote note,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 30,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: note.accentCharacter,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double yPos;
    double xPos = x - (textPainter.width / 2);
    bool isUpsideDownNote = note.isUpsideDown == true;

    if (note.isBeamed) {
      var notesGroup = getBeamedNotesGroup(noteIndex, notes);
      var connectedNotesGroup = notesGroup.notesGroup;

      if (connectedNotesGroup.isNotEmpty) {
        isUpsideDownNote = connectedNotesGroup.first.isUpsideDown == true;
      }

      double staffBottomLineY = staffTop + (lineSpacing * 4);
      double distanceFromStaff = isUpsideDownNote
          ? (staffTop - note.noteY).abs()
          : (note.noteY - staffBottomLineY).abs();

      if (distanceFromStaff > 30) {
        if (isUpsideDownNote) {
          yPos = note.noteY - 85;

          double relativeToStaff = yPos - staffTop;
          double nearestStaffLine =
              (relativeToStaff / lineSpacing).round() * lineSpacing;
          if ((relativeToStaff - nearestStaffLine).abs() < 3) {
            yPos = staffTop + nearestStaffLine;
          }
        } else {
          yPos = note.noteY - 45;

          double relativeToStaff = yPos - staffTop;
          double nearestStaffLine =
              (relativeToStaff / lineSpacing).round() * lineSpacing;
          if ((relativeToStaff - nearestStaffLine).abs() < 3) {
            yPos = staffTop + nearestStaffLine;
          }
        }

        textPainter.paint(canvas, Offset(xPos, yPos + 0.5));
        return;
      }
    }

    if (isUpsideDownNote) {
      double maxAccentY = staffTop;
      double baseYPos = note.noteY - 1;

      if (note.noteY <= staffTop - 10) {
        baseYPos -= 5;
      }

      yPos = math.min(baseYPos, maxAccentY);

      yPos = yPos - 75;
    } else {
      double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
      double minAccentY = staffBottomLineY;
      double baseYPos = note.noteY + 1;

      if (note.noteY >= staffBottomLineY + 10) {
        baseYPos += 5;
      }

      yPos = math.max(baseYPos, minAccentY);
      yPos = yPos - 55;
    }

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  void drawDynamicMarking(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double staffTop,
      bool isCrescendo,
      int startIndex,
      int endIndex,
      List<MusicalNote> notes,
      int rowIndex,
      int? editingDynamicRow,
      int? editingDynamicIndex) {
    if (startIndex == endIndex || endX < startX || endIndex >= notes.length) {
      endX = startX + 10;
    }

    // Offset logic
    if (notes[startIndex].dynamicCharacter.isNotEmpty) {
      startX += 20;
    }
    if (notes[startIndex] == notes[endIndex]) {
      endX += 20;
    } else if (notes[endIndex].dynamicCharacter.isNotEmpty) {
      endX -= 20;
    }

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;
    bool hasDynamicCharacter = false;
    for (int i = startIndex; i <= endIndex; i++) {
      if (notes[i].type != NoteType.space) {
        if (notes[i].noteY > lowestY) {
          lowestY = notes[i].noteY;
        }
        if (notes[i].isUpsideDown == true && notes[i].noteY >= staffTop) {
          hasUpsideDownNoteOnStaff = true;
        }
        if (notes[i].dynamicCharacter.isNotEmpty) {
          hasDynamicCharacter = true;
        }
      }
    }

    double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
    double minDynamicY = staffBottomLineY + 20;
    double y = math.max(lowestY + 50, minDynamicY);

    if (hasUpsideDownNoteOnStaff) {
      y += 30;
    }

    if (hasDynamicCharacter) {
      y += 15;
    }

    double openWidth = 15.0;
    Path path = Path();

    if (isCrescendo) {
      path.moveTo(startX, y);
      path.lineTo(endX, y - openWidth / 2);
      path.moveTo(startX, y);
      path.lineTo(endX, y + openWidth / 2);
    } else {
      path.moveTo(startX, y - openWidth / 2);
      path.lineTo(endX, y);
      path.moveTo(startX, y + openWidth / 2);
      path.lineTo(endX, y);
    }

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawPath(path, paint);

    if (editingDynamicRow == rowIndex && editingDynamicIndex == startIndex) {
      final Paint handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(endX + 10, y), 10, handlePaint);
    }
  }

  void drawRehearsalMarking(Canvas canvas, MusicalNote note, Color noteColour,
      double x, double staffTop, double lineSpacing, double yPos) {
    final bool isUnicode =
        note.rehearsalMarking == '' || note.rehearsalMarking == '';

    final textStyle = TextStyle(
      color: noteColour,
      fontSize: isUnicode ? 32 : 20,
      fontFamily: isUnicode ? 'Bravura' : null,
      fontStyle: isUnicode ? FontStyle.normal : FontStyle.italic,
      fontWeight: isUnicode ? FontWeight.w200 : FontWeight.w600,
    );

    final textSpan = TextSpan(
      text: note.rehearsalMarking,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double xPos = x - (textPainter.width / 2);
    if (isUnicode) yPos = yPos - 40;

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  void drawTriplet(
      Canvas canvas,
      Paint paint,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex,
      double currentRowSpacing) {
    if (noteIndex + 2 >= notes.length) {
      double y = calculateNoteYMainSheet(notes[noteIndex].pitch,
          notes[noteIndex].octave, lineSpacing, staffTop);
      double tripletPlaceholderY = y - 50;

      if (notes[noteIndex].noteY < tripletPlaceholderY + 10) {
        tripletPlaceholderY = notes[noteIndex].noteY - 20;
      }

      if (staffTop + 20 < tripletPlaceholderY) {
        tripletPlaceholderY = staffTop - 20;
      }
      if (staffTop - 40 > tripletPlaceholderY) {
        tripletPlaceholderY = tripletPlaceholderY + 30;
      }

      final textStyle = TextStyle(
        color: paint.color,
        fontSize: 40,
        fontFamily: 'Bravura',
      );
      final textSpan = TextSpan(
        text: '', // Triplet '3'
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      double x1 = x;
      double x2 = x + currentRowSpacing;
      double x3 = x + (2 * currentRowSpacing);

      double middleX = x2;
      double textX = middleX - (textPainter.width / 2);

      textPainter.paint(canvas, Offset(textX, tripletPlaceholderY - 33));

      paint.strokeWidth = 1.0;
      canvas.drawLine(Offset(x1, tripletPlaceholderY),
          Offset(textX - 4, tripletPlaceholderY), paint);
      canvas.drawLine(
          Offset(textX + textPainter.width + 4, tripletPlaceholderY),
          Offset(x3, tripletPlaceholderY),
          paint);

      canvas.drawLine(Offset(x1, tripletPlaceholderY),
          Offset(x1, tripletPlaceholderY + 7), paint);
      canvas.drawLine(Offset(x3, tripletPlaceholderY),
          Offset(x3, tripletPlaceholderY + 7), paint);
      return;
    }

    MusicalNote note1 = notes[noteIndex];
    MusicalNote note2 = notes[noteIndex + 1];
    MusicalNote note3 = notes[noteIndex + 2];

    double x1 = x;
    double x2 = x + currentRowSpacing;
    double x3 = x + (2 * currentRowSpacing);

    double y1 = calculateNoteYMainSheet(
        note1.pitch, note1.octave, lineSpacing, staffTop);
    double y2 = calculateNoteYMainSheet(
        note2.pitch, note2.octave, lineSpacing, staffTop);
    double y3 = calculateNoteYMainSheet(
        note3.pitch, note3.octave, lineSpacing, staffTop);

    double highestNoteY = math.min(y1, math.min(y2, y3));
    double tripletY = highestNoteY - 50;

    for (int i = noteIndex; i <= noteIndex + 2; i++) {
      if (notes[i].noteY < tripletY + 10) {
        tripletY = notes[i].noteY - 20;
      }
    }

    if (staffTop + 20 < tripletY) tripletY = staffTop - 20;
    if (staffTop - 40 > tripletY) tripletY = tripletY + 30;

    bool isAnyNoteInTripletBeamed =
        note1.isBeamed || note2.isBeamed || note3.isBeamed;

    if (isAnyNoteInTripletBeamed) {
      int beamStartIndex = noteIndex;

      while (beamStartIndex > 0 && notes[beamStartIndex - 1].isBeamed) {
        beamStartIndex--;
      }
      MusicalNote firstNoteOfBeam = notes[beamStartIndex];

      if (firstNoteOfBeam.isUpsideDown == true && y1 < staffTop - 20) {
        tripletY = tripletY - 40;
      }
    }

    final textStyle = TextStyle(
      color: paint.color,
      fontSize: 40,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: '', // Triplet '3'
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double middleX = x2;
    double textX = middleX - (textPainter.width / 2);

    textPainter.paint(canvas, Offset(textX, tripletY - 33));

    paint.strokeWidth = 1.0;
    canvas.drawLine(Offset(x1, tripletY), Offset(textX - 4, tripletY), paint);
    canvas.drawLine(Offset(textX + textPainter.width + 4, tripletY),
        Offset(x3, tripletY), paint);

    canvas.drawLine(Offset(x1, tripletY), Offset(x1, tripletY + 7), paint);
    canvas.drawLine(Offset(x3, tripletY), Offset(x3, tripletY + 7), paint);
  }

  bool isSlurAboveForRange(List<MusicalNote> rowNotes, int startIndex,
      int endIndex, double staffCentre) {
    final int minIndex = startIndex < endIndex ? startIndex : endIndex;
    final int maxIndex = startIndex > endIndex ? startIndex : endIndex;

    int notesAboveCenter = 0;
    int notesBelowCenter = 0;

    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];
      if (note.type != NoteType.space) {
        if (note.noteY > staffCentre) {
          notesAboveCenter++;
        } else {
          notesBelowCenter++;
        }
      }
    }

    return notesBelowCenter >= notesAboveCenter;
  }

  double extremalChildY(MusicalNote chord, bool slurIsAbove, double lineSpacing,
      double staffTop) {
    final children = chord.childNotes;
    if (children == null || children.isEmpty) {
      return calculateNoteYMainSheet(
          chord.pitch, chord.octave, lineSpacing, staffTop);
    }

    double extremalY = calculateNoteYMainSheet(
        children.first.pitch, children.first.octave, lineSpacing, staffTop);

    for (int i = 1; i < children.length; i++) {
      final double y = calculateNoteYMainSheet(
          children[i].pitch, children[i].octave, lineSpacing, staffTop);
      if (slurIsAbove) {
        if (y < extremalY) extremalY = y;
      } else {
        if (y > extremalY) extremalY = y;
      }
    }

    return extremalY;
  }
}
