import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';

enum ArticulationType {
  decrescendo,
  crescendo,
  slur,
  mute,
  pinchHarmonic,
  harmonic,
  vibrato,
  bend,
  preBend,
  bendRelease,
  preBendRelease,
}

class _RangeMarkerConfig {
  const _RangeMarkerConfig({
    required this.isStart,
    required this.getEndIndex,
    required this.clearStart,
    required this.clearEnd,
    this.onChildNotes = false,
  });

  final bool Function(MusicalNote note) isStart;
  final int? Function(MusicalNote note) getEndIndex;
  final void Function(MusicalNote note) clearStart;
  final void Function(MusicalNote note) clearEnd;
  final bool onChildNotes;
}

final Map<ArticulationType, _RangeMarkerConfig> _rangeMarkerConfigs = {
  ArticulationType.decrescendo: _RangeMarkerConfig(
    isStart: (n) => n.isDecrescendoStart,
    getEndIndex: (n) => n.decrescendoEndIndex,
    clearStart: (n) => n.isDecrescendoStart = false,
    clearEnd: (n) => n.decrescendoEndIndex = null,
  ),
  ArticulationType.crescendo: _RangeMarkerConfig(
    isStart: (n) => n.isCrescendoStart,
    getEndIndex: (n) => n.crescendoEndIndex,
    clearStart: (n) => n.isCrescendoStart = false,
    clearEnd: (n) => n.crescendoEndIndex = null,
  ),
  ArticulationType.slur: _RangeMarkerConfig(
    isStart: (n) => n.slurEndIndex != null,
    getEndIndex: (n) => n.slurEndIndex,
    clearStart: (n) {},
    clearEnd: (n) => n.slurEndIndex = null,
  ),
  ArticulationType.mute: _RangeMarkerConfig(
    isStart: (n) => n.isMuteStart,
    getEndIndex: (n) => n.muteEndIndex,
    clearStart: (n) => n.isMuteStart = false,
    clearEnd: (n) => n.muteEndIndex = null,
  ),
  ArticulationType.pinchHarmonic: _RangeMarkerConfig(
    isStart: (n) => n.isPinchHarmonicStart,
    getEndIndex: (n) => n.pinchHarmonicEndIndex,
    clearStart: (n) => n.isPinchHarmonicStart = false,
    clearEnd: (n) => n.pinchHarmonicEndIndex = null,
  ),
  ArticulationType.harmonic: _RangeMarkerConfig(
    isStart: (n) => n.isHarmonicStart,
    getEndIndex: (n) => n.harmonicEndIndex,
    clearStart: (n) => n.isHarmonicStart = false,
    clearEnd: (n) => n.harmonicEndIndex = null,
  ),
  ArticulationType.vibrato: _RangeMarkerConfig(
    isStart: (n) => n.isVibratoStart,
    getEndIndex: (n) => n.vibratoEndIndex,
    clearStart: (n) => n.isVibratoStart = false,
    clearEnd: (n) => n.vibratoEndIndex = null,
  ),
  ArticulationType.bend: _RangeMarkerConfig(
    isStart: (n) => n.isBendStart,
    getEndIndex: (n) => n.bendEndIndex,
    clearStart: (n) => n.isBendStart = false,
    clearEnd: (n) => n.bendEndIndex = null,
    onChildNotes: true,
  ),
  ArticulationType.preBend: _RangeMarkerConfig(
    isStart: (n) => n.isPreBendStart,
    getEndIndex: (n) => n.preBendEndIndex,
    clearStart: (n) => n.isPreBendStart = false,
    clearEnd: (n) => n.preBendEndIndex = null,
    onChildNotes: true,
  ),
  ArticulationType.bendRelease: _RangeMarkerConfig(
    isStart: (n) => n.isBendReleaseStart,
    getEndIndex: (n) => n.bendReleaseEndIndex,
    clearStart: (n) => n.isBendReleaseStart = false,
    clearEnd: (n) => n.bendReleaseEndIndex = null,
    onChildNotes: true,
  ),
  ArticulationType.preBendRelease: _RangeMarkerConfig(
    isStart: (n) => n.isPreBendReleaseStart,
    getEndIndex: (n) => n.preBendReleaseEndIndex,
    clearStart: (n) => n.isPreBendReleaseStart = false,
    clearEnd: (n) => n.preBendReleaseEndIndex = null,
    onChildNotes: true,
  ),
};

Iterable<MusicalNote> _candidatesFor(
    _RangeMarkerConfig config, MusicalNote chord) {
  return config.onChildNotes ? (chord.childNotes ?? const []) : [chord];
}

bool shouldShowRangeMarkerRemove(
  ArticulationType type, {
  required List<SheetRows> sheetNoteRows,
  required int? dragStart,
  required int? dragEnd,
  required int? dragRow,
  required int selectedRow,
  required int selectedIndex,
}) {
  final config = _rangeMarkerConfigs[type]!;

  if (dragStart != null && dragEnd != null && dragRow != null) {
    final int start = dragStart < dragEnd ? dragStart : dragEnd;
    final int end = dragStart > dragEnd ? dragStart : dragEnd;

    for (int i = 0; i < sheetNoteRows[dragRow].chords.length; i++) {
      final chord = sheetNoteRows[dragRow].chords[i];
      for (final candidate in _candidatesFor(config, chord)) {
        final endIndex = config.getEndIndex(candidate);
        if (config.isStart(candidate) && endIndex != null) {
          if ((i >= start && i <= end) ||
              (endIndex >= start && endIndex <= end)) {
            return true;
          }
        }
      }
    }
  } else {
    if (selectedIndex < 0) return false;
    for (int i = 0; i < sheetNoteRows[selectedRow].chords.length; i++) {
      final chord = sheetNoteRows[selectedRow].chords[i];
      for (final candidate in _candidatesFor(config, chord)) {
        final endIndex = config.getEndIndex(candidate);
        if (config.isStart(candidate) && endIndex != null) {
          if (i <= selectedIndex && endIndex >= selectedIndex) {
            return true;
          }
        }
      }
    }
  }
  return false;
}

void removeRangeMarker(
  ArticulationType type, {
  required List<SheetRows> sheetNoteRows,
  required int? dragStart,
  required int? dragEnd,
  required int? dragRow,
  required int selectedRow,
  required int selectedIndex,
}) {
  final config = _rangeMarkerConfigs[type]!;

  if (dragStart != null && dragEnd != null && dragRow != null) {
    final int start = dragStart < dragEnd ? dragStart : dragEnd;
    final int end = dragStart > dragEnd ? dragStart : dragEnd;

    for (int i = 0; i < sheetNoteRows[dragRow].chords.length; i++) {
      final chord = sheetNoteRows[dragRow].chords[i];
      for (final candidate in _candidatesFor(config, chord)) {
        final endIndex = config.getEndIndex(candidate);
        if (config.isStart(candidate) && endIndex != null) {
          if ((i >= start && i <= end) ||
              (endIndex >= start && endIndex <= end)) {
            config.clearStart(candidate);
            config.clearEnd(candidate);
          }
        }
      }
    }
  } else {
    if (selectedIndex < 0) return;
    for (int i = 0; i < sheetNoteRows[selectedRow].chords.length; i++) {
      final chord = sheetNoteRows[selectedRow].chords[i];
      for (final candidate in _candidatesFor(config, chord)) {
        final endIndex = config.getEndIndex(candidate);
        if (config.isStart(candidate) && endIndex != null) {
          if (i <= selectedIndex && endIndex >= selectedIndex) {
            config.clearStart(candidate);
            config.clearEnd(candidate);
          }
        }
      }
    }
  }
}
