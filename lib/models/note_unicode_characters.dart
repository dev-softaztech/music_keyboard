class NoteUnicodeCharacters {
  String normal;
  String upsideDown;

  NoteUnicodeCharacters({this.normal = '', this.upsideDown = ''});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteUnicodeCharacters &&
        normal == other.normal &&
        upsideDown == other.upsideDown;
  }

  @override
  int get hashCode => normal.hashCode ^ upsideDown.hashCode;
}
