import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/favourite_chord_key.dart';

class NotesFavouritesToggleButton extends StatelessWidget {
  final bool isFavouritesActive;
  final VoidCallback onPressed;

  const NotesFavouritesToggleButton({
    super.key,
    required this.isFavouritesActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 34,
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

class NotesChordsToggleButton extends StatelessWidget {
  final bool isChordsActive;
  final VoidCallback onPressed;

  const NotesChordsToggleButton({
    super.key,
    required this.isChordsActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 34,
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

class NotesFavouritesGrid extends StatelessWidget {
  final bool favouritesLoading;
  final List<({int id, MusicalNote chord})> favouriteChords;
  final bool isDotted;
  final void Function(MusicalNote chord) onFavouriteChordTapped;
  final void Function(int id) onFavouriteChordUsed;

  const NotesFavouritesGrid({
    super.key,
    required this.favouritesLoading,
    required this.favouriteChords,
    required this.isDotted,
    required this.onFavouriteChordTapped,
    required this.onFavouriteChordUsed,
  });

  @override
  Widget build(BuildContext context) {
    final double gridWidth = MediaQuery.of(context).size.width - 105;

    if (favouritesLoading) {
      return SizedBox(
        height: 220,
        width: gridWidth,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (favouriteChords.isEmpty) {
      return SizedBox(
        height: 220,
        width: gridWidth,
        child: const Center(
          child: Text(
            'You have no favourites.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 220,
      width: gridWidth,
      //below is the pink background
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
          mainAxisSpacing: 5,
          childAspectRatio: 0.31,
        ),
        itemCount: favouriteChords.length,
        itemBuilder: (context, index) {
          final fav = favouriteChords[index];
          final childNotes = fav.chord.childNotes ?? [];

          return FavouriteChordKey(
            childNotes: childNotes,
            isDotted: isDotted,
            onTap: () {
              final children = childNotes.map((child) {
                return MusicalNote(
                  pitch: child.pitch,
                  octave: child.octave,
                  type: child.type,
                  unicodeCharacter: child.unicodeCharacter,
                  accidentalCharacter:
                      isDotted ? 'dotted_rest' : child.accidentalCharacter,
                  duration: child.duration,
                  isUpsideDown: child.isUpsideDown,
                  isBeamed: child.isBeamed,
                );
              }).toList();

              final chordNote = MusicalNote(
                pitch: fav.chord.pitch,
                octave: fav.chord.octave,
                type: NoteType.chord,
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
    );
  }
}
