/// How many bytes [rune] takes once UTF-8 encoded.
int utf8Width(int rune) {
  if (rune < 0x80) return 1;
  if (rune < 0x800) return 2;
  if (rune < 0x10000) return 3;
  return 4;
}

/// How many bytes [text] takes once UTF-8 encoded, without encoding it.
int utf8Length(String text) {
  var length = 0;
  for (final rune in text.runes) {
    length += utf8Width(rune);
  }
  return length;
}
