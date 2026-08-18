import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_icon_button.dart';
import 'peek_search_field.dart';

/// Where a search found something.
@immutable
class _Match {
  const _Match(this.line, this.start);

  final int line;
  final int start;
}

/// A body as text: numbered lines, a search that walks its matches, and
/// only as much of it rendered as fits the screen.
///
/// A body can be megabytes, so the lines are built one at a time; nothing
/// here ever hands the whole body to a single `Text`.
final class PeekTextBodyView extends StatefulWidget {
  /// Creates a viewer over [text].
  ///
  /// [capturedSize] and [totalSize] say how much of the body Peek kept;
  /// when they differ the viewer says so.
  const PeekTextBodyView({
    required this.text,
    this.capturedSize,
    this.totalSize,
    this.wrap = true,
    this.action,
    super.key,
  });

  /// What to show.
  final String text;

  /// How many bytes Peek kept.
  final int? capturedSize;

  /// How many bytes the body had.
  final int? totalSize;

  /// Whether long lines wrap rather than run off the side.
  ///
  /// On by default: a body is read, and reading it should not mean
  /// dragging it sideways. The viewer offers the other way in a button.
  final bool wrap;

  /// A button of the caller's, shown before the view's own.
  final Widget? action;

  @override
  State<PeekTextBodyView> createState() => _PeekTextBodyViewState();
}

class _PeekTextBodyViewState extends State<PeekTextBodyView> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  late List<String> _lines = _split(widget.text);
  late bool _wrap = widget.wrap;
  List<_Match> _matches = const [];
  int _current = 0;

  @override
  void didUpdateWidget(PeekTextBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lines = _split(widget.text);
      _find(_search.text);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final style = theme.mono;
    final lineHeight = (style.fontSize ?? 12) * (style.height ?? 1.4);
    final captured = widget.capturedSize;
    final total = widget.totalSize;
    final gutter = _gutterWidth(style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter - 8, 0),
          child: Row(
            children: [
              Expanded(
                child: PeekSearchField(
                  controller: _search,
                  placeholder: strings.search,
                  onChanged: _find,
                  onClear: () => _find(''),
                ),
              ),
              if (widget.action case final action?) action,
              PeekIconButton(
                icon: _wrap ? Icons.wrap_text : Icons.notes,
                tooltip: _wrap ? strings.stopWrapping : strings.wrapLines,
                size: 18,
                onPressed: () => setState(() => _wrap = !_wrap),
              ),
              PeekCopyButton(text: widget.text, dense: false),
            ],
          ),
        ),
        if (_search.text.isNotEmpty)
          _MatchBar(
            current: _matches.isEmpty ? 0 : _current + 1,
            total: _matches.length,
            onPrevious: _matches.isEmpty ? null : () => _step(-1),
            onNext: _matches.isEmpty ? null : () => _step(1),
          ),
        if (captured != null && total != null && total > captured)
          Padding(
            padding: EdgeInsets.fromLTRB(theme.gutter, 4, theme.gutter, 0),
            child: Text(
              strings.truncatedBody(captured, total),
              style: theme.caption.copyWith(color: theme.secondaryLabel),
            ),
          ),
        SizedBox(height: theme.rowSpacing),
        Expanded(
          child:
              _wrap
                  ? _list(style: style, gutter: gutter, itemExtent: null)
                  : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(
                        MediaQuery.sizeOf(context).width,
                        _estimatedWidth(style, gutter),
                      ),
                      child: _list(
                        style: style,
                        gutter: gutter,
                        itemExtent: lineHeight,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _list({
    required TextStyle style,
    required double gutter,
    required double? itemExtent,
  }) {
    final theme = PeekTheme.of(context);
    final needle = _search.text.trim();
    final focused = _matches.isEmpty ? null : _matches[_current];

    return ListView.builder(
      controller: _scroll,
      itemCount: _lines.length,
      itemExtent: itemExtent,
      // The text ends where the card would: flush against the side, a
      // wrapped line reads as if it were cut off.
      padding: EdgeInsets.only(
        right: itemExtent == null ? theme.gutter : 0,
        bottom: theme.gutter,
      ),
      itemBuilder:
          (context, index) => _Line(
            key: _lineKeys.putIfAbsent(index, GlobalKey.new),
            number: index + 1,
            text: _lines[index],
            style: style,
            gutterWidth: gutter,
            wrap: itemExtent == null,
            highlight: needle,
            focusedStart: focused?.line == index ? focused?.start : null,
          ),
    );
  }

  void _find(String value) {
    final needle = value.trim().toLowerCase();
    final matches = <_Match>[];
    if (needle.isNotEmpty) {
      for (var line = 0; line < _lines.length; line++) {
        final haystack = _lines[line].toLowerCase();
        var at = haystack.indexOf(needle);
        while (at >= 0) {
          matches.add(_Match(line, at));
          at = haystack.indexOf(needle, at + needle.length);
        }
      }
    }
    setState(() {
      _matches = matches;
      _current = 0;
    });
    if (matches.isNotEmpty) _scrollTo(matches.first.line);
  }

  void _step(int by) {
    if (_matches.isEmpty) return;
    setState(() {
      _current = (_current + by) % _matches.length;
    });
    _scrollTo(_matches[_current].line);
  }

  /// Lands on [line]: exactly when every line is the same height, and by
  /// guess-then-correct when they are not.
  void _scrollTo(int line) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final extent = position.maxScrollExtent;
    final target = _lines.isEmpty ? 0.0 : extent * (line / _lines.length);
    _scroll.jumpTo(target.clamp(0, extent));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _lineKeys[line]?.currentContext;
      if (context == null || !mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 120),
        ),
      );
    });
  }

  /// Wide enough for the line numbers, and no wider.
  double _gutterWidth(TextStyle style) =>
      ('${_lines.length}'.length + 1) * (style.fontSize ?? 12) * 0.62;

  /// The longest line, measured the cheap way: a monospace glyph is about
  /// six tenths of its point size, and laying out every line to find out
  /// would cost more than it is worth.
  double _estimatedWidth(TextStyle style, double gutter) {
    var longest = 0;
    for (final line in _lines) {
      if (line.length > longest) longest = line.length;
    }
    return gutter + longest * (style.fontSize ?? 12) * 0.62 + 24;
  }

  static List<String> _split(String text) => text.split('\n');
}

class _MatchBar extends StatelessWidget {
  const _MatchBar({
    required this.current,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter - 8, 0),
      child: Row(
        children: [
          Text(
            strings.matchCount(current, total),
            style: theme.footnote.copyWith(color: theme.secondaryLabel),
          ),
          const Spacer(),
          PeekIconButton(
            icon: Icons.keyboard_arrow_up,
            tooltip: strings.previousMatch,
            size: 18,
            onPressed: onPrevious,
          ),
          PeekIconButton(
            icon: Icons.expand_more,
            tooltip: strings.nextMatch,
            size: 18,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.number,
    required this.text,
    required this.style,
    required this.gutterWidth,
    required this.wrap,
    required this.highlight,
    required this.focusedStart,
    super.key,
  });

  final int number;
  final String text;
  final TextStyle style;
  final double gutterWidth;
  final bool wrap;
  final String highlight;
  final int? focusedStart;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: gutterWidth,
          child: Text(
            '$number',
            textAlign: TextAlign.right,
            style: style.copyWith(color: theme.secondaryLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: _spans(theme)),
            softWrap: wrap,
            maxLines: wrap ? null : 1,
            overflow: wrap ? TextOverflow.clip : TextOverflow.visible,
            style: style,
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _spans(PeekTheme theme) {
    final needle = highlight.trim();
    if (needle.isEmpty || text.isEmpty) return [TextSpan(text: text)];

    final marked = TextStyle(backgroundColor: theme.highlight);
    final focused = TextStyle(
      backgroundColor: theme.accent,
      color: const Color(0xFFFFFFFF),
    );
    final haystack = text.toLowerCase();
    final lower = needle.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;

    while (start < text.length) {
      final at = haystack.indexOf(lower, start);
      if (at < 0) break;
      if (at > start) spans.add(TextSpan(text: text.substring(start, at)));
      final end = at + needle.length;
      spans.add(
        TextSpan(
          text: text.substring(at, end),
          style: at == focusedStart ? focused : marked,
        ),
      );
      start = end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }
}
