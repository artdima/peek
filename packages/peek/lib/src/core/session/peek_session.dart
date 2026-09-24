import 'dart:convert';

import 'package:meta/meta.dart';

import '../model/peek_entry.dart';
import '../model/peek_id.dart';
import 'peek_session_codec.dart';
import 'peek_session_header.dart';

/// A session read back from a `.peek` file.
@immutable
final class PeekSession {
  /// Creates a session.
  PeekSession({
    required this.header,
    List<PeekEntry> entries = const [],
    this.skipped = 0,
  }) : entries = List.unmodifiable(entries);

  /// Where the calls came from.
  final PeekSessionHeader header;

  /// The calls, in the order they first appear in the file.
  final List<PeekEntry> entries;

  /// How many lines could not be read and were left out.
  final int skipped;

  @override
  String toString() =>
      'PeekSession($header, ${entries.length} entries, $skipped skipped)';
}

/// Writes a whole session at once.
///
/// Peek itself never touches a file: the caller decides where the text
/// goes. To grow a file as calls arrive, append
/// [PeekSessionCodec.encodeEntry] lines to it instead — when the file is
/// read, a later line for the same call replaces the earlier one.
final class PeekSessionWriter {
  /// Creates a writer.
  const PeekSessionWriter();

  /// The lines of the session, header first, without line breaks.
  Iterable<String> lines(
    PeekSessionHeader header,
    Iterable<PeekEntry> entries,
  ) sync* {
    const codec = PeekSessionCodec();
    yield codec.encodeHeader(header);
    for (final entry in entries) {
      yield codec.encodeEntry(entry);
    }
  }

  /// The text of a `.peek` file, every line ended by `\n`.
  String write(PeekSessionHeader header, Iterable<PeekEntry> entries) {
    final buffer = StringBuffer();
    lines(header, entries).forEach(buffer.writeln);
    return buffer.toString();
  }
}

/// Reads a session back.
final class PeekSessionReader {
  /// Creates a reader.
  const PeekSessionReader();

  /// Reads the lines of a `.peek` file.
  ///
  /// Blank lines are ignored. A line that is not a call is counted in
  /// [PeekSession.skipped] and left out: one bad line does not cost the
  /// rest. A later line for the same call replaces the earlier one in its
  /// place. A newer format is read as far as it goes — see
  /// [PeekSessionHeader.isNewerFormat].
  ///
  /// Throws a [FormatException] when the first line is not a session header
  /// or the format is older than this Peek reads.
  PeekSession read(Iterable<String> lines) {
    const codec = PeekSessionCodec();
    PeekSessionHeader? header;
    final entries = <PeekId, PeekEntry>{};
    var skipped = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      if (header == null) {
        header = codec.decodeHeader(_withoutByteOrderMark(line));
        continue;
      }
      try {
        final entry = codec.decodeEntry(line);
        entries[entry.id] = entry;
      } on FormatException {
        skipped++;
      }
    }
    if (header == null) {
      throw const FormatException('not a Peek session: there is no header');
    }
    return PeekSession(
      header: header,
      entries: entries.values.toList(),
      skipped: skipped,
    );
  }

  /// Reads the text of a `.peek` file.
  PeekSession readString(String text) =>
      read(const LineSplitter().convert(text));

  static String _withoutByteOrderMark(String line) =>
      line.startsWith('﻿') ? line.substring(1) : line;
}
