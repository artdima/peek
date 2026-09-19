// Outline data, generated from the source icons; a path does not wrap.
// ignore_for_file: lines_longer_than_80_chars

import 'peek_icon_data.dart';

/// Every glyph Peek draws, as outlines rather than a font.
///
/// A font would be a dependency or an asset; an outline is neither. Each
/// glyph is the shape of one icon in a 24 by 24 space, stroked two units
/// thick, and `PeekIcon` scales it to whatever size it is asked for.
///
/// The shapes come from Lucide (ISC); see NOTICE beside the licence.
abstract final class PeekIcons {
  /// What went out: a request and its body.
  static const PeekIconData sent = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M2 12C2 6.477 6.477 2 12 2C17.523 2 22 6.477 22 12C22 17.523 17.523 22 12 22C6.477 22 2 17.523 2 12Z',
      'M16 12L12 8L8 12',
      'M12 16L12 8',
    ],
  );

  /// What came back: a response and its body.
  static const PeekIconData received = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M2 12C2 6.477 6.477 2 12 2C17.523 2 22 6.477 22 12C22 17.523 17.523 22 12 22C6.477 22 2 17.523 2 12Z',
      'M12 8L12 16',
      'M8 12L12 16L16 12',
    ],
  );

  /// A call that came back as asked: a solid disc with the mark cut out.
  static const PeekIconData ok = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    filled: 1,
    paths: [
      'M2 12C2 6.477 6.477 2 12 2C17.523 2 22 6.477 22 12C22 17.523 17.523 22 12 22C6.477 22 2 17.523 2 12Z',
      'M16 9L10.5 14.5L8 12',
    ],
  );

  /// How long the call took, phase by phase.
  static const PeekIconData timing = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M2 12C2 6.477 6.477 2 12 2C17.523 2 22 6.477 22 12C22 17.523 17.523 22 12 22C6.477 22 2 17.523 2 12Z',
      'M12 6L12 12L16 14',
    ],
  );

  /// Cookies, which travel in headers but read as secrets.
  static const PeekIconData cookies = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M3 11L21 11L21 22L3 22Z',
      'M7 11L7 7C7 4.239 9.239 2 12 2C14.761 2 17 4.239 17 7L17 11',
    ],
  );

  /// A list of header names and values.
  static const PeekIconData headers = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M3 5L3.01 5',
      'M3 12L3.01 12',
      'M3 19L3.01 19',
      'M8 5L21 5',
      'M8 12L21 12',
      'M8 19L21 19',
    ],
  );

  /// The call written out as a shell command.
  static const PeekIconData curl = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: ['M12 19L20 19', 'M4 17L10 11L4 5'],
  );

  /// Which logger reported the call.
  static const PeekIconData source = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M12 20L12.01 20',
      'M2 8.82C7.694 3.727 16.306 3.727 22 8.82',
      'M5 12.859C8.888 9.048 15.112 9.048 19 12.859',
      'M8.5 16.429C10.444 14.523 13.556 14.523 15.5 16.429',
    ],
  );

  /// Hands the call to the platform.
  static const PeekIconData share = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M15 5C15 3.343 16.343 2 18 2C19.657 2 21 3.343 21 5C21 6.657 19.657 8 18 8C16.343 8 15 6.657 15 5Z',
      'M3 12C3 10.343 4.343 9 6 9C7.657 9 9 10.343 9 12C9 13.657 7.657 15 6 15C4.343 15 3 13.657 3 12Z',
      'M15 19C15 17.343 16.343 16 18 16C19.657 16 21 17.343 21 19C21 20.657 19.657 22 18 22C16.343 22 15 20.657 15 19Z',
      'M8.59 13.51L15.42 17.49',
      'M15.41 6.51L8.59 10.49',
    ],
  );

  /// Keeps a call where eviction cannot reach it.
  static const PeekIconData pin = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M12 17L12 22',
      'M9 10.76C9 11.519 8.57 12.212 7.89 12.55L6.11 13.45C5.43 13.788 5 14.481 5 15.24L5 16C5 16.552 5.448 17 6 17L18 17C18.552 17 19 16.552 19 16L19 15.24C19 14.481 18.57 13.788 17.89 13.45L16.11 12.55C15.43 12.212 15 11.519 15 10.76L15 7C15 6.448 15.448 6 16 6C17.105 6 18 5.105 18 4C18 2.895 17.105 2 16 2L8 2C6.895 2 6 2.895 6 4C6 5.105 6.895 6 8 6C8.552 6 9 6.448 9 7Z',
    ],
  );

  /// Where the call went: its address.
  static const PeekIconData link = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M10 13C10.869 14.162 12.2 14.889 13.647 14.992C15.094 15.096 16.514 14.566 17.54 13.54L20.54 10.54C22.435 8.578 22.408 5.46 20.479 3.531C18.55 1.602 15.432 1.575 13.47 3.47L11.75 5.18',
      'M14 11C13.131 9.838 11.8 9.111 10.353 9.008C8.906 8.904 7.486 9.434 6.46 10.46L3.46 13.46C1.565 15.422 1.592 18.54 3.521 20.469C5.45 22.398 8.568 22.425 10.53 20.53L12.24 18.82',
    ],
  );

  /// The call written out as plain text.
  static const PeekIconData text = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M6 22C4.895 22 4 21.105 4 20L4 4C4 2.895 4.895 2 6 2L14 2C14.639 1.999 15.253 2.253 15.704 2.706L19.292 6.294C19.746 6.745 20.001 7.36 20 8L20 20C20 21.105 19.105 22 18 22Z',
      'M14 2L14 7C14 7.552 14.448 8 15 8L20 8',
      'M10 9L8 9',
      'M16 13L8 13',
      'M16 17L8 17',
    ],
  );

  /// The call written out as Markdown.
  static const PeekIconData markdown = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: ['M4 9L20 9', 'M4 15L20 15', 'M10 3L8 21', 'M16 3L14 21'],
  );

  /// JSON, in the shape it is written: a pair of braces.
  static const PeekIconData braces = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M8 3L7 3C5.895 3 5 3.895 5 5L5 10C5 11.105 4.105 12 3 12C4.105 12 5 12.895 5 14L5 19C5 20.1 5.9 21 7 21L8 21',
      'M16 21L17 21C18.105 21 19 20.105 19 19L19 14C19 12.9 19.9 12 21 12C19.895 12 19 11.105 19 10L19 5C19 3.895 18.105 3 17 3L16 3',
    ],
  );

  /// A body read as a tree of branches.
  static const PeekIconData tree = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M8 5L21 5',
      'M13 12L21 12',
      'M13 19L21 19',
      'M3 10C3 11.105 3.895 12 5 12L8 12',
      'M3 5L3 17C3 18.105 3.895 19 5 19L8 19',
    ],
  );

  /// Opens everything at once.
  static const PeekIconData expand = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: ['M15 3L21 3L21 9', 'M21 3L14 10', 'M3 21L10 14', 'M9 21L3 21L3 15'],
  );

  /// Closes everything at once.
  static const PeekIconData collapse = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M14 10L21 3',
      'M20 10L14 10L14 4',
      'M3 21L10 14',
      'M4 14L10 14L10 20',
    ],
  );

  /// Leaves without doing anything.
  static const PeekIconData close = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: ['M18 6L6 18', 'M6 6L18 18'],
  );

  /// How fast the call was: a dial with a needle.
  static const PeekIconData gauge = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M3.34 19C1.553 15.906 1.553 12.094 3.34 9C5.126 5.906 8.427 4 12 4C15.573 4 18.874 5.906 20.66 9C22.447 12.094 22.447 15.906 20.66 19',
      'M12 14L16 10',
    ],
  );

  /// Largest value first.
  static const PeekIconData sortDescending = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M3 16L7 20L11 16',
      'M7 20L7 4',
      'M11 4L21 4',
      'M11 8L18 8',
      'M11 12L15 12',
    ],
  );

  /// Smallest value first.
  static const PeekIconData sortAscending = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M3 8L7 4L11 8',
      'M7 4L7 20',
      'M11 12L15 12',
      'M11 16L18 16',
      'M11 20L21 20',
    ],
  );

  /// Everything else that can be done with a call.
  static const PeekIconData more = PeekIconData(
    width: 24,
    height: 24,
    strokeWidth: 2,
    paths: [
      'M11 12C11 11.448 11.448 11 12 11C12.552 11 13 11.448 13 12C13 12.552 12.552 13 12 13C11.448 13 11 12.552 11 12Z',
      'M18 12C18 11.448 18.448 11 19 11C19.552 11 20 11.448 20 12C20 12.552 19.552 13 19 13C18.448 13 18 12.552 18 12Z',
      'M4 12C4 11.448 4.448 11 5 11C5.552 11 6 11.448 6 12C6 12.552 5.552 13 5 13C4.448 13 4 12.552 4 12Z',
    ],
  );
}
