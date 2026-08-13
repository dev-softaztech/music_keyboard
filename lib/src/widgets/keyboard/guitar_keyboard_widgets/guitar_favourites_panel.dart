import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

class GuitarFavouritesToggleButton extends StatelessWidget {
  final bool isFavouritesActive;
  final VoidCallback onPressed;

  const GuitarFavouritesToggleButton({
    super.key,
    required this.isFavouritesActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isFavouritesActive ? Colors.red.shade50 : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isFavouritesActive ? Colors.red : Colors.black,
              width: 1,
            ),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          Icons.favorite,
          color: isFavouritesActive ? Colors.red : Colors.black,
          size: 18,
        ),
      ),
    );
  }
}

class GuitarChordsToggleButton extends StatelessWidget {
  final bool isChordsActive;
  final VoidCallback onPressed;

  const GuitarChordsToggleButton({
    super.key,
    required this.isChordsActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isChordsActive ? Colors.black : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          'Chord',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isChordsActive ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class GuitarFavouritesGrid extends StatelessWidget {
  final bool favouritesLoading;
  final List<({int id, MusicalNote chord})> favouriteChords;
  final void Function(MusicalNote chord) onFavouriteChordTapped;
  final void Function(int id) onFavouriteChordUsed;

  const GuitarFavouritesGrid({
    super.key,
    required this.favouritesLoading,
    required this.favouriteChords,
    required this.onFavouriteChordTapped,
    required this.onFavouriteChordUsed,
  });

  @override
  Widget build(BuildContext context) {
    if (favouritesLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (favouriteChords.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'You have no favourites.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 222, 228),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            crossAxisSpacing: 2,
            mainAxisSpacing: 4,
            childAspectRatio: 0.55,
          ),
          itemCount: favouriteChords.length,
          itemBuilder: (context, index) {
            final fav = favouriteChords[index];
            final childNotes = fav.chord.childNotes ?? [];

            return GuitarFavouriteChordKey(
              childNotes: childNotes,
              onTap: () {
                final children = childNotes.map((child) {
                  return MusicalNote(
                    pitch: child.pitch,
                    octave: child.octave,
                    type: child.type,
                    unicodeCharacter: child.unicodeCharacter,
                    accidentalCharacter: child.accidentalCharacter,
                    duration: child.duration,
                    isUpsideDown: child.isUpsideDown,
                    isBeamed: child.isBeamed,
                  );
                }).toList();

                final chordNote = MusicalNote(
                  pitch: fav.chord.pitch,
                  octave: fav.chord.octave,
                  type: fav.chord.type,
                  unicodeCharacter: fav.chord.unicodeCharacter,
                  duration: fav.chord.duration,
                  childNotes: children,
                );

                onFavouriteChordTapped(chordNote);
                onFavouriteChordUsed(fav.id);
              },
            );
          },
        ),
      ),
    );
  }
}

class GuitarFavouriteChordKey extends StatefulWidget {
  final List<MusicalNote> childNotes;
  final VoidCallback onTap;

  const GuitarFavouriteChordKey({
    super.key,
    required this.childNotes,
    required this.onTap,
  });

  @override
  State<GuitarFavouriteChordKey> createState() =>
      _GuitarFavouriteChordKeyState();
}

class _GuitarFavouriteChordKeyState extends State<GuitarFavouriteChordKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed ? Colors.grey[400] : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color.fromARGB(255, 130, 130, 130),
            width: 1.0,
          ),
        ),
        child: CustomPaint(
          painter: _GuitarChordKeyPainter(childNotes: widget.childNotes),
        ),
      ),
    );
  }
}

class _GuitarChordKeyPainter extends CustomPainter {
  final List<MusicalNote> childNotes;

  _GuitarChordKeyPainter({required this.childNotes});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.7;

    final lineSpacing = size.height / 9;
    final staffTop = (size.height - 5 * lineSpacing) / 2;

    for (int i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(0, staffTop + i * lineSpacing),
        Offset(size.width, staffTop + i * lineSpacing),
        linePaint,
      );
    }

    for (final childNote in childNotes) {
      final fret = childNote.unicodeCharacter;
      if (fret.isEmpty) continue;

      final stringY = staffTop + (childNote.octave * lineSpacing);
      final noteX = size.width / 2;

      final textPainter = TextPainter(
        text: TextSpan(
          text: fret,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final xPos = noteX - textPainter.width / 2;
      final yPos = stringY - textPainter.height / 2;

      canvas.drawRect(
        Rect.fromLTRB(
          xPos - 0.5,
          yPos + 1.5,
          xPos + textPainter.width + 0.5,
          yPos + textPainter.height - 1.5,
        ),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      textPainter.paint(canvas, Offset(xPos, yPos));
    }
  }

  @override
  bool shouldRepaint(_GuitarChordKeyPainter old) =>
      old.childNotes != childNotes;
}
