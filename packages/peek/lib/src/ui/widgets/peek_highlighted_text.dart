import 'package:flutter/material.dart';

import '../theme/peek_theme.dart';

/// [text] with every occurrence of [highlight] marked.
///
/// Matching is case-insensitive, like the search that produced it. With
/// nothing to mark this is a plain [Text], so callers pay nothing for the
/// feature when no one is searching.
final class PeekHighlightedText extends StatelessWidget {
  /// Creates a run of text marking [highlight] wherever it appears.
  const PeekHighlightedText(
    this.text, {
    this.highlight = '',
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  /// What to show.
  final String text;

  /// What to mark inside it; surrounding whitespace is ignored.
  final String highlight;

  /// The style of the whole run.
  final TextStyle? style;

  /// How many lines to allow.
  final int? maxLines;

  /// What to do with text that does not fit.
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final needle = highlight.trim();
    if (needle.isEmpty || text.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    return Text.rich(
      TextSpan(children: _spans(needle, PeekTheme.of(context).highlight)),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _spans(String needle, Color color) {
    final spans = <InlineSpan>[];
    final haystack = text.toLowerCase();
    final lower = needle.toLowerCase();
    final marked = TextStyle(backgroundColor: color);
    var start = 0;

    while (start < text.length) {
      final at = haystack.indexOf(lower, start);
      if (at < 0) break;
      if (at > start) spans.add(TextSpan(text: text.substring(start, at)));
      final end = at + needle.length;
      spans.add(TextSpan(text: text.substring(at, end), style: marked));
      start = end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }
}
