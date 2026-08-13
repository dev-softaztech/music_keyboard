import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:provider/provider.dart';

abstract class ChordHandlingHost {
  BuildContext get context;
  Sheet get sheet;
  bool get isBeamLockActive;
  SheetDatabaseHelper get dbHelper;
  void markAsChanged();
  bool get mounted;
  void hostSetState(VoidCallback fn);
}

class ChordHandlingController {
  ChordHandlingController({required this.host});

  final ChordHandlingHost host;
  Sheet get sheet => host.sheet;
  int? favouriteChordId;
  String? _lastCheckedChordKey;
  int favouritesVersion = 0;

  double _noteStaffOffset(String pitch, int octave) {
    const offsets = {
      'C': 5.5,
      'D': 5.0,
      'E': 4.5,
      'F': 4.0,
      'G': 3.5,
      'A': 3.0,
      'B': 2.5,
    };

    return (offsets[pitch] ?? 4.0) + (4 - octave) * 3.5;
  }

  bool _chordIsUpsideDown(List<MusicalNote> children) {
    const double staffCentreOffset = 2.0;
    double maxDistance = -1;
    bool upsideDown = false;
    for (final child in children) {
      final offset = _noteStaffOffset(child.pitch, child.octave);
      final distance = (offset - staffCentreOffset).abs();
      if (distance > maxDistance) {
        maxDistance = distance;

        upsideDown = offset < staffCentreOffset;
      }
    }
    return upsideDown;
  }

  void handleAddToChord(MusicalNote note) {
    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();
    final accidentalProvider = host.context.read<SelectedAccidentalProvider>();
    final selectedAccidental = accidentalProvider.selectedAccidental;

    final selectedRow = selectedNoteProvider.selectedRow;
    final selectedIndex = selectedNoteProvider.selectedIndex;

    if (sheet.sheetRows.isEmpty ||
        selectedRow < 0 ||
        selectedRow >= sheet.sheetRows.length) return;

    final rowChords = sheet.sheetRows[selectedRow].chords;
    if (selectedIndex < 0 || selectedIndex >= rowChords.length) return;

    final chord = rowChords[selectedIndex];
    if (chord.type != NoteType.chord) return;

    chord.childNotes ??= [];

    chord.childNotes!.removeWhere(
        (child) => child.pitch == note.pitch && child.octave == note.octave);

    final noteWithAccidental = MusicalNote(
      pitch: note.pitch,
      octave: note.octave,
      type: note.type,
      isBeamed: note.isBeamed,
      unicodeCharacter: note.unicodeCharacter,
      accidentalCharacter: selectedAccidental,
    );

    chord.childNotes!.add(noteWithAccidental);

    final newUpsideDown = _chordIsUpsideDown(chord.childNotes!);
    chord.isUpsideDown = newUpsideDown;
    for (final child in chord.childNotes!) {
      child.isUpsideDown = newUpsideDown;
    }

    if (host.isBeamLockActive) {
      chord.isBeamed = true;
    }

    host.markAsChanged();
  }

  void handleConvertToChord(MusicalNote tappedNote) {
    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();
    final accidentalProvider = host.context.read<SelectedAccidentalProvider>();
    final selectedAccidental = accidentalProvider.selectedAccidental;

    final selectedRow = selectedNoteProvider.selectedRow;
    final selectedIndex = selectedNoteProvider.selectedIndex;

    if (sheet.sheetRows.isEmpty ||
        selectedRow < 0 ||
        selectedRow >= sheet.sheetRows.length) return;

    final rowChords = sheet.sheetRows[selectedRow].chords;
    if (selectedIndex < 0 || selectedIndex >= rowChords.length) return;

    final existing = rowChords[selectedIndex];
    if (existing.type == NoteType.chord) return;

    final tappedAsChild = MusicalNote(
      pitch: tappedNote.pitch,
      octave: tappedNote.octave,
      type: tappedNote.type,
      isBeamed: tappedNote.isBeamed,
      unicodeCharacter: tappedNote.unicodeCharacter,
      accidentalCharacter: selectedAccidental,
    );

    final children = [
      if (existing.type != NoteType.space)
        MusicalNote(
          pitch: existing.pitch,
          octave: existing.octave,
          type: existing.type,
          isBeamed: existing.isBeamed,
          unicodeCharacter: existing.unicodeCharacter,
          accidentalCharacter: existing.accidentalCharacter,
          duration: existing.duration,
          isUpsideDown: existing.isUpsideDown,
        ),
      tappedAsChild,
    ];

    final stemUpsideDown = _chordIsUpsideDown(children);
    for (final child in children) {
      child.isUpsideDown = stemUpsideDown;
    }

    final chordNote = MusicalNote(
      pitch: existing.pitch,
      octave: existing.octave,
      type: NoteType.chord,
      isBeamed: existing.isBeamed,
      duration: existing.duration,
      unicodeCharacter: existing.unicodeCharacter,
      isUpsideDown: stemUpsideDown,
      childNotes: children,
    );

    rowChords[selectedIndex] = chordNote;

    host.markAsChanged();
  }

  void handleRemoveFromChord(MusicalNote note) {
    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();
    final selectedRow = selectedNoteProvider.selectedRow;
    final selectedIndex = selectedNoteProvider.selectedIndex;

    if (sheet.sheetRows.isEmpty ||
        selectedRow < 0 ||
        selectedRow >= sheet.sheetRows.length) return;

    final rowChords = sheet.sheetRows[selectedRow].chords;
    if (selectedIndex < 0 || selectedIndex >= rowChords.length) return;

    final chord = rowChords[selectedIndex];
    if (chord.type != NoteType.chord) return;

    chord.childNotes?.removeWhere(
        (child) => child.pitch == note.pitch && child.octave == note.octave);

    host.markAsChanged();
  }

  Future<void> checkFavouriteStatus(MusicalNote chord) async {
    final key = (chord.childNotes ?? [])
        .map((n) => n.type == NoteType.fret
            ? '${n.octave}:${n.unicodeCharacter}'
            : '${n.pitch}${n.octave}')
        .toList()
      ..sort();
    final keyStr = key.join(',');
    if (keyStr == _lastCheckedChordKey) return;
    _lastCheckedChordKey = keyStr;
    final id = await host.dbHelper.findMatchingFavouriteChordId(chord);
    if (host.mounted) {
      host.hostSetState(() {
        favouriteChordId = id;
      });
    }
  }

  Future<void> toggleFavourite(MusicalNote chord) async {
    if (favouriteChordId != null) {
      await host.dbHelper.deleteFavouriteChord(favouriteChordId!);
      if (host.mounted) {
        host.hostSetState(() {
          favouriteChordId = null;
          favouritesVersion++;
        });
      }
    } else {
      final id = await host.dbHelper.insertFavouriteChord(
        chord,
        keyboardType: sheet.keyboardType == KeyboardType.guitarTab
            ? 'guitarTab'
            : 'sheetMusic',
      );
      if (host.mounted) {
        host.hostSetState(() {
          favouriteChordId = id;
          favouritesVersion++;
        });
      }
    }
  }

  void handleFavouriteChordTapped(
    MusicalNote chord,
    bool Function(int rowIndex, CurrentSelectedNoteProvider provider,
            List<MusicalNote> notes)
        updateRowSpacing,
  ) {
    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();
    selectedNoteProvider.addNote(chord, sheet.sheetRows, host.context);
    updateRowSpacing(
      selectedNoteProvider.selectedRow,
      selectedNoteProvider,
      sheet.sheetRows[selectedNoteProvider.selectedRow].chords,
    );
    host.markAsChanged();
  }
}
