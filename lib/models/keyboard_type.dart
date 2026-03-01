enum KeyboardType {
  sheet,
  drumTab,
  guitarTab,
}

extension KeyboardTypeExtension on KeyboardType {
  String get displayName {
    switch (this) {
      case KeyboardType.sheet:
        return 'Sheet Music';
      case KeyboardType.drumTab:
        return 'Drum Tab';
      case KeyboardType.guitarTab:
        return 'Guitar Tab';
    }
  }

  String get description {
    switch (this) {
      case KeyboardType.sheet:
        return 'Standard music notation';
      case KeyboardType.drumTab:
        return 'Drum tablature notation';
      case KeyboardType.guitarTab:
        return 'Guitar tablature notation';
    }
  }

  String toJson() => toString().split('.').last;

  static KeyboardType fromJson(String value) {
    return KeyboardType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => KeyboardType.sheet,
    );
  }

  /// Returns the number of lines in a staff for this keyboard type
  int get lineCount {
    switch (this) {
      case KeyboardType.sheet:
        return 5;
      case KeyboardType.drumTab:
        return 5;
      case KeyboardType.guitarTab:
        return 6;
    }
  }

  /// Returns the starting x position for notes on a row for this keyboard type
  double get startingNoteX {
    switch (this) {
      case KeyboardType.sheet:
        return 85.0;
      case KeyboardType.drumTab:
        return 85.0;
      case KeyboardType.guitarTab:
        return 110.0;
    }
  }
}
