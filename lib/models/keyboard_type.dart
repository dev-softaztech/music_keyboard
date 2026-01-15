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
}
