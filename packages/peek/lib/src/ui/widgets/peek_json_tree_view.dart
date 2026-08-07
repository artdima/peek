import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_icon_button.dart';
import 'peek_json_node.dart';
import 'peek_search_field.dart';
import 'peek_sheet.dart';
import 'peek_tappable.dart';
import 'peek_text_body_view.dart';

/// A JSON body as a tree that can be opened a branch at a time.
///
/// Bodies past [asyncFrom] are decoded off the main thread, so a big
/// response does not freeze the screen it is opening on. A body that
/// turns out not to be JSON is shown as text, with a line saying why.
final class PeekJsonTreeView extends StatefulWidget {
  /// Creates a tree over [source].
  const PeekJsonTreeView({
    required this.source,
    this.capturedSize,
    this.totalSize,
    super.key,
  });

  /// The JSON text.
  final String source;

  /// How many bytes Peek kept, for the fallback text view.
  final int? capturedSize;

  /// How many bytes the body had, for the fallback text view.
  final int? totalSize;

  /// The size from which decoding moves off the main thread.
  static const int asyncFrom = 64 * 1024;

  /// How deep the tree opens itself on first sight.
  static const int openTo = 2;

  @override
  State<PeekJsonTreeView> createState() => _PeekJsonTreeViewState();
}

class _PeekJsonTreeViewState extends State<PeekJsonTreeView> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _expanded = {};

  PeekJsonNode? _root;
  bool _decoding = true;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  @override
  void didUpdateWidget(PeekJsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The open branches are the reader's, not the body's: a call that
    // came back again reopens where they left it.
    if (oldWidget.source != widget.source) unawaited(_decode());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final root = _root;

    if (_decoding) return const SizedBox.shrink();
    if (_invalid || root == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, 4),
            child: Text(
              strings.notJson,
              style: theme.footnote.copyWith(color: theme.failure),
            ),
          ),
          Expanded(
            child: PeekTextBodyView(
              text: widget.source,
              capturedSize: widget.capturedSize,
              totalSize: widget.totalSize,
            ),
          ),
        ],
      );
    }

    final rows = root.rows(_expanded);
    final needle = _search.text;

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
              PeekIconButton(
                icon: Icons.unfold_more,
                tooltip: strings.expandAll,
                size: 18,
                onPressed:
                    () => setState(() => _expanded.addAll(root.branchPaths)),
              ),
              PeekIconButton(
                icon: Icons.unfold_less,
                tooltip: strings.collapseAll,
                size: 18,
                onPressed: () => setState(_expanded.clear),
              ),
              PeekCopyButton(text: widget.source, dense: false),
            ],
          ),
        ),
        SizedBox(height: theme.rowSpacing),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            padding: EdgeInsets.only(bottom: theme.gutter),
            itemBuilder: (context, index) {
              final row = rows[index];
              return _Row(
                row: row,
                open: _expanded.contains(row.node.path),
                highlighted: row.node.matches(needle),
                onTap: row.node.isBranch ? () => _toggle(row.node.path) : null,
                onHold: () => unawaited(_actions(context, row.node, strings)),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _decode() async {
    setState(() {
      _decoding = true;
      _invalid = false;
    });

    Object? decoded;
    var invalid = false;
    try {
      decoded =
          widget.source.length >= PeekJsonTreeView.asyncFrom
              ? await compute(jsonDecode, widget.source)
              : jsonDecode(widget.source);
    } on FormatException {
      invalid = true;
    }
    if (!mounted) return;

    final root = invalid ? null : PeekJsonNode.of(decoded);
    setState(() {
      _root = root;
      _invalid = invalid;
      _decoding = false;
      if (root != null && _expanded.isEmpty) {
        _expanded.addAll(_openTo(root, PeekJsonTreeView.openTo));
      }
    });
  }

  void _toggle(String path) => setState(() {
    _expanded.contains(path) ? _expanded.remove(path) : _expanded.add(path);
  });

  void _find(String value) {
    final root = _root;
    setState(() {
      if (root != null) _expanded.addAll(root.pathsTo(value));
    });
  }

  Future<void> _actions(
    BuildContext context,
    PeekJsonNode node,
    PeekStrings strings,
  ) async {
    final action = await showPeekActions<_NodeAction>(
      context,
      title: node.path.isEmpty ? null : node.path,
      actions: [
        PeekAction(value: _NodeAction.value, label: strings.copyValue),
        if (node.path.isNotEmpty)
          PeekAction(value: _NodeAction.path, label: strings.copyPath),
      ],
    );
    if (action == null || !context.mounted) return;
    final text = action == _NodeAction.value ? node.toPrettyJson() : node.path;
    await peekCopy(context, text);
  }

  /// Every branch down to [depth], so a body opens showing its shape.
  Set<String> _openTo(PeekJsonNode root, int depth) {
    final paths = <String>{};
    void walk(PeekJsonNode node, int level) {
      if (!node.isBranch || level > depth) return;
      paths.add(node.path);
      for (final child in node.children) {
        walk(child, level + 1);
      }
    }

    walk(root, 1);
    return paths;
  }
}

enum _NodeAction { value, path }

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.open,
    required this.highlighted,
    required this.onTap,
    required this.onHold,
  });

  final PeekJsonRow row;
  final bool open;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final node = row.node;
    final style = theme.mono;

    // A tree is read by scanning, so its rows stay denser than the 48 a
    // tap target asks for: every value here is also reachable from the
    // row's menu, and the text view shows the same body without a tree.
    return PeekTappable(
      onTap: onTap,
      onLongPress: onHold,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        color: highlighted ? theme.highlight : null,
        padding: EdgeInsets.fromLTRB(
          theme.gutter + row.depth * 14,
          2,
          theme.gutter,
          2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              child:
                  node.isBranch && !row.isClosing
                      ? Icon(
                        open ? Icons.expand_more : Icons.chevron_right,
                        size: 14,
                        color: theme.secondaryLabel,
                      )
                      : null,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: _spans(node, theme, style, strings)),
                maxLines: open || !node.isBranch ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What the row reads.
  ///
  /// An open branch reads as the document does — its bracket, then its
  /// children, then the bracket that closes it. Only a closed one stands
  /// in for what it holds, and only that one is worth counting.
  List<InlineSpan> _spans(
    PeekJsonNode node,
    PeekTheme theme,
    TextStyle style,
    PeekStrings strings,
  ) {
    final bracket = style.copyWith(color: _colorFor(node, theme));
    if (row.isClosing) return [TextSpan(text: node.closing, style: bracket)];

    return [
      if (node.name case final name?)
        TextSpan(
          text: '$name: ',
          style: style.copyWith(fontWeight: FontWeight.w600),
        ),
      if (node.index case final index?)
        TextSpan(
          text: '$index: ',
          style: style.copyWith(color: theme.secondaryLabel),
        ),
      TextSpan(
        text: open && node.isBranch ? node.opening : node.text,
        style: bracket,
      ),
      if (node.isBranch && !open)
        TextSpan(
          text: '  ${strings.items(node.count)}',
          style: theme.caption.copyWith(color: theme.secondaryLabel),
        ),
    ];
  }

  static Color _colorFor(PeekJsonNode node, PeekTheme theme) => switch (node
      .kind) {
    PeekJsonKind.string => theme.success,
    PeekJsonKind.number => theme.redirect,
    PeekJsonKind.boolean => theme.clientError,
    PeekJsonKind.nothing => theme.secondaryLabel,
    PeekJsonKind.object || PeekJsonKind.array => theme.secondaryLabel,
  };
}
