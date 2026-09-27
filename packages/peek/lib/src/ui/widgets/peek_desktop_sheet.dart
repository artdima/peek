import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoTextField;
import 'package:flutter/material.dart' show Icons, SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/sink/peek_desktop_link.dart';
import '../icons/peek_icon.dart';
import '../icons/peek_icons.dart';
import '../peek_links.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_code_field.dart';
import 'peek_copy_button.dart';
import 'peek_filled_button.dart';
import 'peek_list_row.dart';
import 'peek_list_section.dart';
import 'peek_sheet.dart';
import 'peek_status_dot.dart';

/// The link to a desktop viewer the app attached, if it attached one.
PeekDesktopLink? peekDesktopLinkOf(BuildContext context) =>
    PeekScope.read(
      context,
    ).peek.adapters.whereType<PeekDesktopLink>().firstOrNull;

/// Opens the sheet about the desktop viewer: where the link stands when the
/// app has one, or how to set one up when it has not.
Future<void> showPeekDesktop(BuildContext context) {
  final link = peekDesktopLinkOf(context);
  return showPeekSheet<void>(
    context,
    builder:
        (context) =>
            link == null
                ? const PeekDesktopSetup()
                : PeekDesktopLinkSheet(link: link),
  );
}

/// What the menu says about the desktop viewer: an invitation, or where the
/// link stands.
String peekDesktopMenuLabel(PeekStrings strings, PeekDesktopLink? link) {
  if (link == null) return strings.connectToDesktop;
  final state = link.linkState;
  final name = state.desktopName ?? strings.desktop;
  return switch (state.status) {
    PeekDesktopLinkStatus.connected => strings.connectedToDesktop(name),
    PeekDesktopLinkStatus.connecting => strings.connectingToDesktop(name),
    PeekDesktopLinkStatus.waiting => strings.waitingForDesktop(name),
    PeekDesktopLinkStatus.denied => strings.desktopDenied,
    PeekDesktopLinkStatus.unpaired => strings.connectToDesktop,
    PeekDesktopLinkStatus.stopped => strings.desktopDisconnected,
  };
}

/// How to get a desktop viewer, for an app without a link to one: what to
/// add, what to write, and where to read more. The addresses are shown
/// rather than opened — Peek takes no plugin for a link.
final class PeekDesktopSetup extends StatelessWidget {
  /// Creates the sheet.
  const PeekDesktopSetup({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return _SheetBody(
      title: strings.connectToDesktop,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            theme.gutter,
            0,
            theme.gutter,
            theme.gutter,
          ),
          child: Text(
            strings.desktopAbout,
            style: theme.footnote.copyWith(color: theme.secondaryLabel),
          ),
        ),
        PeekListSection(
          title: strings.desktopAddDependency,
          children: const [_CopyableLine(PeekLinks.dependency, mono: true)],
        ),
        PeekListSection(
          title: strings.desktopSetUp,
          children: const [_CopyableLine(PeekLinks.setup, mono: true)],
        ),
        PeekListSection(
          title: strings.desktopLinks,
          children: [
            _CopyableLine(PeekLinks.peekPro, label: strings.desktopRepository),
            _CopyableLine(PeekLinks.peekRemote, label: strings.desktopPackage),
            _CopyableLine(PeekLinks.remoteGuide, label: strings.desktopGuide),
          ],
        ),
      ],
    );
  }
}

/// Where the link stands, and what a person can do about it: pick a Mac the
/// network heard, or type its address, and enter the code it shows; once
/// connected, disconnect or forget it.
final class PeekDesktopLinkSheet extends StatefulWidget {
  /// Creates the sheet over [link].
  const PeekDesktopLinkSheet({required this.link, super.key});

  /// The link the app attached.
  final PeekDesktopLink link;

  @override
  State<PeekDesktopLinkSheet> createState() => _PeekDesktopLinkSheetState();
}

enum _Problem { chooseFirst, badAddress }

class _PeekDesktopLinkSheetState extends State<PeekDesktopLinkSheet> {
  static const _codeLength = 4;

  final GlobalKey<PeekCodeFieldState> _code = GlobalKey();
  final TextEditingController _address = TextEditingController();
  StreamSubscription<PeekDesktopLinkState>? _states;
  StreamSubscription<List<PeekDesktopFound>>? _search;
  late PeekDesktopLinkState _state = widget.link.linkState;
  List<PeekDesktopFound> _found = const [];
  bool _searchFailed = false;
  PeekDesktopFound? _chosen;
  // The sheet started the connection under way, so it stays to see how it
  // ends instead of switching to the status.
  bool _pairing = false;
  bool _wrongCode = false;
  _Problem? _problem;

  @override
  void initState() {
    super.initState();
    _wrongCode = _isWrongCode(_state);
    if (_state.host case final host?) {
      _address.text = _addressOf(host, _state.port);
    }
    _states = widget.link.linkChanges.listen(_follow);
    _search = widget.link.watchDesktops().listen(
      (found) => setState(() {
        _found = found;
        _searchFailed = false;
      }),
      onError: (Object _) => setState(() => _searchFailed = true),
    );
  }

  @override
  void dispose() {
    unawaited(_states?.cancel());
    unawaited(_search?.cancel());
    _address.dispose();
    super.dispose();
  }

  static bool _isWrongCode(PeekDesktopLinkState state) =>
      state.status == PeekDesktopLinkStatus.denied &&
      state.denial == PeekDesktopDenial.code;

  void _follow(PeekDesktopLinkState state) {
    final refused = _isWrongCode(state);
    final shake = refused && _pairing;
    setState(() {
      _state = state;
      if (state.status != PeekDesktopLinkStatus.connecting &&
          state.status != PeekDesktopLinkStatus.waiting) {
        _pairing = false;
      }
      if (refused) _wrongCode = true;
    });
    if (shake) {
      _code.currentState
        ?..reject()
        ..focus();
    }
  }

  void _choose(PeekDesktopFound found) {
    setState(() {
      _chosen = found;
      _problem = null;
    });
    _address.clear();
    if (found.isPaired) {
      _start(
        found.host,
        found.port,
        name: found.name,
        serverId: found.serverId,
      );
    } else if (_code.currentState?.code.length == _codeLength) {
      _connect();
    } else {
      _code.currentState?.focus();
    }
  }

  void _typedAddress(String _) {
    if (_chosen == null && _problem == null) return;
    setState(() {
      _chosen = null;
      _problem = null;
    });
  }

  void _typedCode(String code) {
    if (code.isEmpty || (!_wrongCode && _problem == null)) return;
    setState(() {
      _wrongCode = false;
      _problem = null;
    });
  }

  void _connect() {
    final code = _code.currentState?.code ?? '';
    if (code.length < _codeLength) return;
    if (_chosen case final chosen?) {
      _start(
        chosen.host,
        chosen.port,
        code: code,
        name: chosen.name,
        serverId: chosen.serverId,
      );
      return;
    }
    final text = _address.text.trim();
    final address = peekDesktopAddress(text);
    if (address == null) {
      setState(
        () =>
            _problem =
                text.isEmpty ? _Problem.chooseFirst : _Problem.badAddress,
      );
      return;
    }
    _start(address.host, address.port, code: code);
  }

  void _connectAgain(String host, int port) {
    final name = _state.desktopName;
    _start(host, port, name: name == '$host:$port' ? null : name);
  }

  void _start(
    String host,
    int port, {
    String? code,
    String? name,
    String? serverId,
  }) {
    FocusScope.of(context).unfocus();
    setState(() {
      _pairing = true;
      _wrongCode = false;
      _problem = null;
    });
    unawaited(
      widget.link.connectDesktop(
        host,
        port,
        code: code,
        name: name,
        serverId: serverId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final state = _state;
    final status = state.status;
    final name = state.desktopName;
    final underWay =
        status == PeekDesktopLinkStatus.connecting ||
        status == PeekDesktopLinkStatus.waiting;
    final linked =
        status == PeekDesktopLinkStatus.connected || (underWay && !_pairing);

    return _SheetBody(
      title: strings.connectToDesktop,
      children: [
        PeekListSection(
          footer: _note(strings, state),
          children: [
            PeekListRow(
              title: strings.desktopStatus,
              leading:
                  status == PeekDesktopLinkStatus.connecting
                      ? _Spinner(theme)
                      : PeekStatusDot(_colour(theme, status)),
              value: _status(strings, state),
            ),
            PeekListRow(
              title: strings.desktopPairedWith,
              value: name ?? strings.desktopUnpaired,
            ),
          ],
        ),
        if (linked)
          PeekListSection(
            footer: name == null ? null : strings.forgetDesktopHint,
            children: [
              PeekListRow(
                title: strings.disconnect,
                titleStyle: TextStyle(color: theme.accent),
                onTap: () => unawaited(widget.link.disconnectDesktop()),
              ),
              if (name != null)
                PeekListRow(
                  title: strings.forgetDesktop,
                  titleStyle: TextStyle(color: theme.failure),
                  onTap: () => unawaited(widget.link.forgetDesktop()),
                ),
            ],
          )
        else
          ..._pairingSections(strings, theme, name, underWay),
      ],
    );
  }

  List<Widget> _pairingSections(
    PeekStrings strings,
    PeekTheme theme,
    String? name,
    bool underWay,
  ) {
    final state = _state;
    final busy = _pairing && state.status == PeekDesktopLinkStatus.connecting;
    final host = state.host;
    final problem = switch (_problem) {
      _Problem.chooseFirst => strings.desktopChooseFirst,
      _Problem.badAddress => strings.desktopBadAddress,
      null => _wrongCode ? strings.desktopCodeWrong : null,
    };

    return [
      if (state.status == PeekDesktopLinkStatus.stopped && host != null)
        PeekListSection(
          children: [
            PeekListRow(
              title: strings.connectAgain,
              titleStyle: TextStyle(color: theme.accent),
              onTap:
                  () => _connectAgain(
                    host,
                    state.port ?? PeekDesktopLink.defaultPort,
                  ),
            ),
          ],
        ),
      PeekListSection(
        title: strings.desktopsNearby,
        children: [
          if (_found.isEmpty)
            PeekListRow(
              title:
                  _searchFailed
                      ? strings.desktopSearchUnavailable
                      : strings.desktopSearching,
              leading: _searchFailed ? null : _Spinner(theme),
              enabled: false,
            ),
          for (final found in _found)
            PeekListRow(
              title: found.name,
              subtitle:
                  !found.isCompatible
                      ? strings.desktopIncompatible
                      : found.isPaired
                      ? strings.desktopPaired
                      : _addressOf(found.host, found.port),
              leading: PeekIcon(
                PeekIcons.desktop,
                size: 18,
                color: found.isCompatible ? theme.accent : theme.secondaryLabel,
              ),
              trailing:
                  found == _chosen
                      ? Icon(Icons.check, size: 18, color: theme.accent)
                      : null,
              enabled: found.isCompatible && !busy,
              onTap: () => _choose(found),
            ),
        ],
      ),
      PeekListSection(
        title: strings.desktopAddress,
        footer: strings.desktopAddressHint,
        children: [
          CupertinoTextField(
            controller: _address,
            enabled: !busy,
            decoration: null,
            padding: EdgeInsets.symmetric(
              horizontal: theme.gutter,
              vertical: 12,
            ),
            placeholder: strings.desktopAddressPlaceholder,
            placeholderStyle: theme.body.copyWith(color: theme.tertiaryLabel),
            style: theme.body.copyWith(color: theme.label),
            cursorColor: theme.accent,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _typedAddress,
            onSubmitted: (_) => _connect(),
          ),
        ],
      ),
      PeekListSection(
        title: strings.desktopCode,
        footer: strings.desktopCodeHint,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                PeekCodeField(
                  key: _code,
                  enabled: !busy,
                  error: _wrongCode,
                  semanticLabel: strings.desktopCodeLabel,
                  onChanged: _typedCode,
                  onCompleted: (_) => _connect(),
                ),
                if (problem != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      theme.gutter,
                      10,
                      theme.gutter,
                      0,
                    ),
                    child: Text(
                      problem,
                      textAlign: TextAlign.center,
                      style: theme.footnote.copyWith(color: theme.failure),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      if (underWay || (name != null && !_pairing))
        PeekListSection(
          footer: underWay ? null : strings.forgetDesktopHint,
          children: [
            if (underWay)
              PeekListRow(
                title: strings.disconnect,
                titleStyle: TextStyle(color: theme.accent),
                onTap: () => unawaited(widget.link.disconnectDesktop()),
              ),
            if (name != null && !_pairing)
              PeekListRow(
                title: strings.forgetDesktop,
                titleStyle: TextStyle(color: theme.failure),
                onTap: () => unawaited(widget.link.forgetDesktop()),
              ),
          ],
        ),
    ];
  }

  static String? _note(PeekStrings strings, PeekDesktopLinkState state) =>
      switch (state.status) {
        PeekDesktopLinkStatus.waiting => strings.desktopUnreachable(
          state.desktopName ?? strings.desktop,
        ),
        PeekDesktopLinkStatus.denied => switch (state.denial) {
          PeekDesktopDenial.code => null,
          PeekDesktopDenial.protocolVersion => strings.desktopOtherVersion,
          _ => state.message,
        },
        _ => null,
      };

  static String _status(PeekStrings strings, PeekDesktopLinkState state) =>
      switch (state.status) {
        PeekDesktopLinkStatus.unpaired => strings.desktopUnpaired,
        PeekDesktopLinkStatus.connecting => strings.connectingToDesktop(
          state.desktopName ?? strings.desktop,
        ),
        PeekDesktopLinkStatus.connected => strings.connectedToDesktop(
          state.desktopName ?? strings.desktop,
        ),
        PeekDesktopLinkStatus.waiting => strings.waitingForDesktop(
          state.desktopName ?? strings.desktop,
        ),
        PeekDesktopLinkStatus.denied => strings.desktopDenied,
        PeekDesktopLinkStatus.stopped => strings.desktopDisconnected,
      };

  static Color _colour(PeekTheme theme, PeekDesktopLinkStatus status) =>
      switch (status) {
        PeekDesktopLinkStatus.connected => theme.success,
        PeekDesktopLinkStatus.connecting ||
        PeekDesktopLinkStatus.waiting => theme.accent,
        PeekDesktopLinkStatus.denied => theme.failure,
        PeekDesktopLinkStatus.unpaired ||
        PeekDesktopLinkStatus.stopped => theme.secondaryLabel,
      };
}

/// Reads an address the way a person types it — `host`, `host:port`,
/// `[v6]:port`, a bare IPv6 address, with or without `ws://` — into where
/// to connect; `null` for text that is none of them. The port defaults to
/// [PeekDesktopLink.defaultPort].
({String host, int port})? peekDesktopAddress(String text) {
  var address = text.trim().replaceFirst(
    RegExp('^[a-z]+://', caseSensitive: false),
    '',
  );
  while (address.endsWith('/')) {
    address = address.substring(0, address.length - 1);
  }
  if (address.isEmpty || address.contains(RegExp(r'[\s/]'))) return null;

  int? port(String text) {
    final port = int.tryParse(text);
    return port != null && port > 0 && port <= 65535 ? port : null;
  }

  if (address.startsWith('[')) {
    final close = address.indexOf(']');
    if (close < 2) return null;
    final host = address.substring(1, close);
    final rest = address.substring(close + 1);
    if (rest.isEmpty) return (host: host, port: PeekDesktopLink.defaultPort);
    final parsed = rest.startsWith(':') ? port(rest.substring(1)) : null;
    return parsed == null ? null : (host: host, port: parsed);
  }
  final colons = ':'.allMatches(address).length;
  if (colons != 1) {
    return (host: address, port: PeekDesktopLink.defaultPort);
  }
  final colon = address.indexOf(':');
  final host = address.substring(0, colon);
  final parsed = port(address.substring(colon + 1));
  return host.isEmpty || parsed == null ? null : (host: host, port: parsed);
}

String _addressOf(String host, int? port) {
  final shown = host.contains(':') ? '[$host]' : host;
  return port == null || port == PeekDesktopLink.defaultPort
      ? shown
      : '$shown:$port';
}

class _Spinner extends StatelessWidget {
  const _Spinner(this.theme);

  final PeekTheme theme;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 14,
    child: CupertinoActivityIndicator(radius: 7, color: theme.secondaryLabel),
  );
}

/// The frame both sheets share: a title, the sections, a way out.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(theme.gutter, 6, theme.gutter, 10),
          child: Row(
            children: [
              Icon(Icons.desktop_mac_outlined, size: 20, color: theme.label),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.headline)),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            theme.gutter,
            0,
            theme.gutter,
            theme.rowSpacing,
          ),
          child: PeekFilledButton(
            label: strings.close,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

/// A value to take away: selectable, with a copy button beside it.
class _CopyableLine extends StatelessWidget {
  const _CopyableLine(this.value, {this.label, this.mono = false});

  final String value;
  final String? label;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final label = this.label;
    final style =
        mono
            ? theme.mono.copyWith(fontSize: theme.footnote.fontSize)
            : theme.footnote.copyWith(color: theme.secondaryLabel);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: theme.minRowHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(theme.gutter, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(label, style: theme.body),
                    ),
                  SelectableText(value, style: style),
                ],
              ),
            ),
            PeekCopyButton(text: value),
          ],
        ),
      ),
    );
  }
}
