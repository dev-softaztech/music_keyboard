class MusicalNote {
  final String pitch; // e.g., C, D, E
  final int octave; // e.g., 4 (Middle C is in octave 4)
  final NoteType type; // e.g., Whole, Half, Quarter, Eighth, Sixteenth
  bool isBeamed;
  bool isTiedToNext;
  bool isCrescendoStart;
  bool isDecrescendoStart;
  int? crescendoEndIndex;
  int? decrescendoEndIndex;
  bool isBendStart;
  bool isPreBendStart;
  bool isBendReleaseStart;
  bool isPreBendReleaseStart;
  bool isHammerLeftHandStart;
  bool hasSlideUp;
  bool hasSlideDown;
  int? bendEndIndex;
  int? preBendEndIndex;
  int? bendReleaseEndIndex;
  int? preBendReleaseEndIndex;
  int? hammerLeftHandEndIndex;
  bool isMuteStart;
  bool isPinchHarmonicStart;
  bool isHarmonicStart;
  bool isVibratoStart;
  int? muteEndIndex;
  int? pinchHarmonicEndIndex;
  int? harmonicEndIndex;
  int? vibratoEndIndex;
  final String unicodeCharacter;
  final String accidentalCharacter; // Unicode character for the accidental
  int? slurEndIndex;
  double noteY;
  bool? isUpsideDown;
  double duration; // Duration value for bar line calculation
  String topTimeSignatureCharacter;
  String bottomTimeSignatureCharacter;
  String dynamicCharacter;
  String accentCharacter;
  bool isTriplet;
  double tempoNumber;
  bool swing;
  String swingText;
  String rehearsalMarking;
  String keySignatureName;
  String keySignatureClefType;
  String clefType; // 'Treble', 'Bass', 'Alto', 'Tenor'
  String
      tapRightHandCharacter; // Unicode character for tap-right-hand technique
  bool hasPickDownward;
  bool hasPickUpward;
  List<MusicalNote>? childNotes; // For chords - multiple notes at same position

  MusicalNote(
      {required this.pitch,
      required this.octave,
      required this.type,
      this.isBeamed = false,
      this.isTiedToNext = false,
      this.isCrescendoStart = false,
      this.isDecrescendoStart = false,
      this.crescendoEndIndex,
      this.decrescendoEndIndex,
      this.isBendStart = false,
      this.isPreBendStart = false,
      this.isBendReleaseStart = false,
      this.isPreBendReleaseStart = false,
      this.isHammerLeftHandStart = false,
      this.hasSlideUp = false,
      this.hasSlideDown = false,
      this.bendEndIndex,
      this.preBendEndIndex,
      this.bendReleaseEndIndex,
      this.preBendReleaseEndIndex,
      this.hammerLeftHandEndIndex,
      this.isMuteStart = false,
      this.isPinchHarmonicStart = false,
      this.isHarmonicStart = false,
      this.isVibratoStart = false,
      this.muteEndIndex,
      this.pinchHarmonicEndIndex,
      this.harmonicEndIndex,
      this.vibratoEndIndex,
      this.slurEndIndex,
      this.unicodeCharacter = "",
      this.accidentalCharacter = "",
      this.noteY = 0.0,
      this.isUpsideDown = null,
      this.duration = 0.0,
      this.topTimeSignatureCharacter = "",
      this.bottomTimeSignatureCharacter = "",
      this.dynamicCharacter = "",
      this.accentCharacter = "",
      this.isTriplet = false,
      this.tempoNumber = 0.0,
      this.swing = false,
      this.swingText = "",
      this.rehearsalMarking = "",
      this.keySignatureName = "",
      this.keySignatureClefType = "",
      this.clefType = "",
      this.tapRightHandCharacter = "",
      this.hasPickUpward = false,
      this.hasPickDownward = false,
      this.childNotes});

  MusicalNote copy() {
    return MusicalNote(
        pitch: pitch,
        octave: octave,
        type: type,
        isBeamed: isBeamed,
        isTiedToNext: isTiedToNext,
        isCrescendoStart: isCrescendoStart,
        isDecrescendoStart: isDecrescendoStart,
        crescendoEndIndex: crescendoEndIndex,
        decrescendoEndIndex: decrescendoEndIndex,
        isBendStart: isBendStart,
        isPreBendStart: isPreBendStart,
        isBendReleaseStart: isBendReleaseStart,
        isPreBendReleaseStart: isPreBendReleaseStart,
        isHammerLeftHandStart: isHammerLeftHandStart,
        hasSlideUp: hasSlideUp,
        hasSlideDown: hasSlideDown,
        bendEndIndex: bendEndIndex,
        preBendEndIndex: preBendEndIndex,
        bendReleaseEndIndex: bendReleaseEndIndex,
        preBendReleaseEndIndex: preBendReleaseEndIndex,
        hammerLeftHandEndIndex: hammerLeftHandEndIndex,
        isMuteStart: isMuteStart,
        isPinchHarmonicStart: isPinchHarmonicStart,
        isHarmonicStart: isHarmonicStart,
        isVibratoStart: isVibratoStart,
        muteEndIndex: muteEndIndex,
        pinchHarmonicEndIndex: pinchHarmonicEndIndex,
        harmonicEndIndex: harmonicEndIndex,
        vibratoEndIndex: vibratoEndIndex,
        slurEndIndex: slurEndIndex,
        unicodeCharacter: unicodeCharacter,
        accidentalCharacter: accidentalCharacter,
        noteY: noteY,
        isUpsideDown: isUpsideDown,
        duration: duration,
        topTimeSignatureCharacter: topTimeSignatureCharacter,
        bottomTimeSignatureCharacter: bottomTimeSignatureCharacter,
        dynamicCharacter: dynamicCharacter,
        accentCharacter: accentCharacter,
        isTriplet: isTriplet,
        tempoNumber: tempoNumber,
        swing: swing,
        swingText: swingText,
        rehearsalMarking: rehearsalMarking,
        keySignatureName: keySignatureName,
        keySignatureClefType: keySignatureClefType,
        clefType: clefType,
        tapRightHandCharacter: tapRightHandCharacter,
        hasPickDownward: hasPickDownward,
        hasPickUpward: hasPickUpward,
        childNotes: childNotes?.map((note) => note.copy()).toList());
  }

  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'octave': octave,
      'type': type.toJson(),
      'isBeamed': isBeamed,
      'isTiedToNext': isTiedToNext,
      'isCrescendoStart': isCrescendoStart,
      'isDecrescendoStart': isDecrescendoStart,
      'crescendoEndIndex': crescendoEndIndex,
      'decrescendoEndIndex': decrescendoEndIndex,
      'isBendStart': isBendStart,
      'isPreBendStart': isPreBendStart,
      'isBendReleaseStart': isBendReleaseStart,
      'isPreBendReleaseStart': isPreBendReleaseStart,
      'isHammerLeftHandStart': isHammerLeftHandStart,
      'hasSlideUp': hasSlideUp,
      'hasSlideDown': hasSlideDown,
      'bendEndIndex': bendEndIndex,
      'preBendEndIndex': preBendEndIndex,
      'bendReleaseEndIndex': bendReleaseEndIndex,
      'preBendReleaseEndIndex': preBendReleaseEndIndex,
      'hammerLeftHandEndIndex': hammerLeftHandEndIndex,
      'isMuteStart': isMuteStart,
      'isPinchHarmonicStart': isPinchHarmonicStart,
      'isHarmonicStart': isHarmonicStart,
      'isVibratoStart': isVibratoStart,
      'muteEndIndex': muteEndIndex,
      'pinchHarmonicEndIndex': pinchHarmonicEndIndex,
      'harmonicEndIndex': harmonicEndIndex,
      'vibratoEndIndex': vibratoEndIndex,
      'unicodeCharacter': unicodeCharacter,
      'accidentalCharacter': accidentalCharacter,
      'slurEndIndex': slurEndIndex,
      'noteY': noteY,
      'isUpsideDown': isUpsideDown,
      'duration': duration,
      'topTimeSignatureCharacter': topTimeSignatureCharacter,
      'bottomTimeSignatureCharacter': bottomTimeSignatureCharacter,
      'dynamicCharacter': dynamicCharacter,
      'accentCharacter': accentCharacter,
      'isTriplet': isTriplet,
      'tempoNumber': tempoNumber,
      'swing': swing,
      'swingText': swingText,
      'rehearsalMarking': rehearsalMarking,
      'keySignatureName': keySignatureName,
      'keySignatureClefType': keySignatureClefType,
      'clefType': clefType,
      'tapRightHandCharacter': tapRightHandCharacter,
      'hasPickDownward': hasPickDownward,
      'hasPickUpward': hasPickUpward,
      'childNotes': childNotes?.map((note) => note.toJson()).toList(),
    };
  }

  factory MusicalNote.fromJson(Map<String, dynamic> json) {
    return MusicalNote(
      pitch: json['pitch'] ?? '',
      octave: json['octave'] ?? 4,
      type: NoteTypeExtension.fromJson(json['type'] ?? 'quarter'),
      isBeamed: json['isBeamed'] ?? false,
      isTiedToNext: json['isTiedToNext'] ?? false,
      isCrescendoStart: json['isCrescendoStart'] ?? false,
      isDecrescendoStart: json['isDecrescendoStart'] ?? false,
      crescendoEndIndex: json['crescendoEndIndex'],
      decrescendoEndIndex: json['decrescendoEndIndex'],
      isBendStart: json['isBendStart'] ?? false,
      isPreBendStart: json['isPreBendStart'] ?? false,
      isBendReleaseStart: json['isBendReleaseStart'] ?? false,
      isPreBendReleaseStart: json['isPreBendReleaseStart'] ?? false,
      isHammerLeftHandStart: json['isHammerLeftHandStart'] ?? false,
      hasSlideUp: json['hasSlideUp'] ?? false,
      hasSlideDown: json['hasSlideDown'] ?? false,
      bendEndIndex: json['bendEndIndex'],
      preBendEndIndex: json['preBendEndIndex'],
      bendReleaseEndIndex: json['bendReleaseEndIndex'],
      preBendReleaseEndIndex: json['preBendReleaseEndIndex'],
      hammerLeftHandEndIndex: json['hammerLeftHandEndIndex'],
      isMuteStart: json['isMuteStart'] ?? false,
      isPinchHarmonicStart: json['isPinchHarmonicStart'] ?? false,
      isHarmonicStart: json['isHarmonicStart'] ?? false,
      muteEndIndex: json['muteEndIndex'],
      pinchHarmonicEndIndex: json['pinchHarmonicEndIndex'],
      harmonicEndIndex: json['harmonicEndIndex'],
      vibratoEndIndex: json['vibratoEndIndex'],
      unicodeCharacter: json['unicodeCharacter'] ?? '',
      accidentalCharacter: json['accidentalCharacter'] ?? '',
      slurEndIndex: json['slurEndIndex'],
      noteY: json['noteY'] ?? 0.0,
      isUpsideDown: json['isUpsideDown'],
      duration: json['duration'] ?? 0.0,
      topTimeSignatureCharacter: json['topTimeSignatureCharacter'] ?? '',
      bottomTimeSignatureCharacter: json['bottomTimeSignatureCharacter'] ?? '',
      dynamicCharacter: json['dynamicCharacter'] ?? '',
      accentCharacter: json['accentCharacter'] ?? '',
      isTriplet: json['isTriplet'] ?? false,
      tempoNumber: json['tempoNumber'] ?? 0.0,
      swing: json['swing'] ?? false,
      swingText: json['swingText'] ?? '',
      rehearsalMarking: json['rehearsalMarking'] ?? '',
      keySignatureName: json['keySignatureName'] ?? '',
      keySignatureClefType: json['keySignatureClefType'] ?? '',
      clefType: json['clefType'] ?? '',
      tapRightHandCharacter: json['tapRightHandCharacter'] ?? '',
      hasPickDownward: json['hasPickDownward'] ?? false,
      hasPickUpward: json['hasPickUpward'] ?? false,
      childNotes: (json['childNotes'] as List<dynamic>?)
          ?.map((childJson) => MusicalNote.fromJson(childJson))
          .toList(),
    );
  }
}

enum NoteType {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
  sixtyFourth,
  clef,
  rest,
  accidental,
  bar,
  timeSignature,
  space,
  keySignature,
  fret,
  chord
}

extension NoteTypeExtension on NoteType {
  String toJson() => toString().split('.').last;

  static NoteType fromJson(String value) {
    return NoteType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => NoteType.quarter,
    );
  }
}
