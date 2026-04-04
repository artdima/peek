import 'package:flutter/material.dart';

import '../../core/query/peek_search_query.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';

/// Where a chip lets the search look. Request and response bodies move
/// together: telling them apart matters when reading a call, not when
/// looking for one.
enum _Scope {
  url({PeekSearchScope.url}),
  headers({PeekSearchScope.headers}),
  body({PeekSearchScope.requestBody, PeekSearchScope.responseBody}),
  error({PeekSearchScope.error});

  const _Scope(this.scopes);

  final Set<PeekSearchScope> scopes;

  String label(PeekStrings strings) => switch (this) {
    _Scope.url => strings.url,
    _Scope.headers => strings.headers,
    _Scope.body => strings.body,
    _Scope.error => strings.error,
  };
}

/// The search field above the list, with the scopes it looks in.
///
/// Typing goes to [PeekController.searchFor], which waits out a pause
/// before filtering; the field itself stays responsive meanwhile. The
/// scope chips appear once there is a search to narrow.
final class PeekSearchBar extends StatefulWidget {
  /// Creates the search field.
  const PeekSearchBar({this.autofocus = false, super.key});

  /// Whether the field takes focus as soon as it is shown.
  final bool autofocus;

  @override
  State<PeekSearchBar> createState() => _PeekSearchBarState();
}

class _PeekSearchBarState extends State<PeekSearchBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Anything that changes the query elsewhere — a cleared filter, a
    // restored one — has to show up in the field.
    final text = PeekScope.of(context).searchText;
    if (text == _text.text) return;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final muted = theme.monoTextStyle.color?.withValues(alpha: 0.55);
    final hasText = controller.searchText.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 4, theme.gutter, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            style: theme.monoTextStyle.copyWith(fontSize: 13),
            onChanged: controller.searchFor,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: theme.monoTextStyle.color?.withValues(alpha: 0.06),
              hintText: strings.search,
              hintStyle: theme.monoTextStyle.copyWith(
                fontSize: 13,
                color: muted,
              ),
              prefixIcon: Icon(Icons.search, size: 18, color: muted),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 36,
              ),
              suffixIcon:
                  hasText
                      ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: strings.clearSearch,
                        onPressed: () => _clear(controller),
                      )
                      : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(theme.radius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (hasText || _focus.hasFocus) _scopes(controller, strings),
        ],
      ),
    );
  }

  Widget _scopes(PeekController controller, PeekStrings strings) {
    final selected = controller.filter.query.scopes;
    final active =
        _Scope.values
            .where((scope) => selected.containsAll(scope.scopes))
            .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final scope in _Scope.values)
            FilterChip(
              label: Text(scope.label(strings)),
              labelStyle: const TextStyle(fontSize: 12),
              selected: active.contains(scope),
              // The last scope left cannot be turned off: a search with
              // nowhere to look would quietly match everything.
              onSelected:
                  active.length == 1 && active.contains(scope)
                      ? null
                      : (value) => _toggle(controller, scope, value: value),
            ),
        ],
      ),
    );
  }

  void _toggle(PeekController controller, _Scope scope, {required bool value}) {
    final scopes = {...controller.filter.query.scopes};
    value ? scopes.addAll(scope.scopes) : scopes.removeAll(scope.scopes);
    controller.searchIn(scopes);
  }

  void _clear(PeekController controller) {
    _text.clear();
    controller.searchFor('');
  }

  void _onFocusChanged() => setState(() {});
}
