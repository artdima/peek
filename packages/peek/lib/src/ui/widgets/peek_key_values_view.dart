import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_cookie.dart';
import '../../core/model/peek_headers.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_icon_button.dart';
import 'peek_key_value_row.dart';
import 'peek_list_section.dart';
import 'peek_search_field.dart';

/// One row of a [PeekKeyValuesView].
@immutable
final class PeekKeyValue {
  /// Creates a row named [name] holding [value].
  const PeekKeyValue(this.name, this.value, {this.note});

  /// What the row is called.
  final String name;

  /// What it holds.
  final String value;

  /// A line under the value, such as a cookie's attributes.
  final String? note;
}

/// A table of names and values: headers, cookies, query parameters.
///
/// Long tables get a filter; every table can be reordered by name and
/// copied whole or a row at a time. A value Peek masked is marked as
/// masked rather than shown as if the server sent asterisks.
final class PeekKeyValuesView extends StatefulWidget {
  /// Creates a table titled [title] over [pairs].
  const PeekKeyValuesView({
    required this.title,
    required this.pairs,
    super.key,
  });

  /// The heading over the table.
  final String title;

  /// The rows, in the order they arrived.
  final List<PeekKeyValue> pairs;

  /// How many rows a table may have before it offers a filter.
  static const int filterFrom = 7;

  @override
  State<PeekKeyValuesView> createState() => _PeekKeyValuesViewState();
}

class _PeekKeyValuesViewState extends State<PeekKeyValuesView> {
  final TextEditingController _filter = TextEditingController();
  bool _byName = false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final masked = PeekScope.of(context).peek.options.redaction.replacement;
    final shown = _shown();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.pairs.length >= PeekKeyValuesView.filterFrom)
          Padding(
            padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, 8),
            child: PeekSearchField(
              controller: _filter,
              placeholder: strings.search,
              clearLabel: strings.clearSearch,
              onChanged: (_) => setState(() {}),
              onClear: () => setState(_filter.clear),
            ),
          ),
        PeekListSection(
          title: widget.title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PeekIconButton(
                icon: _byName ? Icons.sort_by_alpha : Icons.sort,
                tooltip: _byName ? strings.sortByOrder : strings.sortByName,
                size: 16,
                onPressed: () => setState(() => _byName = !_byName),
              ),
              PeekCopyButton(
                text: shown.isEmpty ? null : _asText(shown),
                tooltip: strings.copyAll,
              ),
            ],
          ),
          children: [
            if (shown.isEmpty) PeekKeyValueRow(name: strings.empty, value: ''),
            for (final pair in shown)
              PeekKeyValueRow(
                name: pair.name,
                value: pair.value,
                subtitle: pair.note,
                emphasised: pair.value == masked,
                trailing: PeekCopyButton(text: '${pair.name}: ${pair.value}'),
              ),
          ],
        ),
      ],
    );
  }

  List<PeekKeyValue> _shown() {
    final needle = _filter.text.trim().toLowerCase();
    final pairs = [
      for (final pair in widget.pairs)
        if (needle.isEmpty || pair.name.toLowerCase().contains(needle)) pair,
    ];
    if (_byName) {
      pairs.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return pairs;
  }

  String _asText(List<PeekKeyValue> pairs) =>
      pairs.map((pair) => '${pair.name}: ${pair.value}').join('\n');
}

/// The headers of a request or a response, as a table.
final class PeekHeadersView extends StatelessWidget {
  /// Creates a table over [headers], titled [title].
  const PeekHeadersView(this.headers, {this.title, super.key});

  /// What to show.
  final PeekHeaders headers;

  /// An override for the heading.
  final String? title;

  @override
  Widget build(BuildContext context) => PeekKeyValuesView(
    title: title ?? PeekScope.stringsOf(context).headers,
    pairs: [
      for (final header in headers.entries)
        PeekKeyValue(header.key, header.value),
    ],
  );
}

/// The cookies of a request or a response, with their attributes.
final class PeekCookiesView extends StatelessWidget {
  /// Creates a table over [cookies], titled [title].
  const PeekCookiesView(this.cookies, {this.title, super.key});

  /// What to show.
  final List<PeekCookie> cookies;

  /// An override for the heading.
  final String? title;

  @override
  Widget build(BuildContext context) => PeekKeyValuesView(
    title: title ?? PeekScope.stringsOf(context).cookies,
    pairs: [
      for (final cookie in cookies)
        PeekKeyValue(cookie.name, cookie.value, note: _attributes(cookie)),
    ],
  );

  static String? _attributes(PeekCookie cookie) {
    if (cookie.attributes.isEmpty) return null;
    return [
      for (final MapEntry(:key, :value) in cookie.attributes.entries)
        // A flag such as HttpOnly has a name and nothing after it.
        if (value == null || value.isEmpty) key else '$key=$value',
    ].join('; ');
  }
}

/// The query parameters of a URL, decoded.
final class PeekQueryParamsView extends StatelessWidget {
  /// Creates a table over [parameters], titled [title].
  const PeekQueryParamsView(this.parameters, {this.title, super.key});

  /// The parameters, a key at a time; repeated keys repeat.
  final Map<String, List<String>> parameters;

  /// An override for the heading.
  final String? title;

  @override
  Widget build(BuildContext context) => PeekKeyValuesView(
    title: title ?? PeekScope.stringsOf(context).queryParameters,
    pairs: [
      for (final MapEntry(:key, :value) in parameters.entries)
        for (final single in value) PeekKeyValue(key, single),
    ],
  );
}
