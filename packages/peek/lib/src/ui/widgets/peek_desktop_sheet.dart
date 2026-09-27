import 'dart:async';

import 'package:flutter/material.dart' show Icons, SelectableText;
import 'package:flutter/widgets.dart';

import '../../core/sink/peek_desktop_link.dart';
import '../peek_links.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
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

/// Where the link stands, and the two things a person can do about it.
///
/// The address and the code go in here too, once there is a way to find a
/// desktop on the network.
final class PeekDesktopLinkSheet extends StatelessWidget {
  /// Creates the sheet over [link].
  const PeekDesktopLinkSheet({required this.link, super.key});

  /// The link the app attached.
  final PeekDesktopLink link;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return StreamBuilder<PeekDesktopLinkState>(
      stream: link.linkChanges,
      initialData: link.linkState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? link.linkState;
        final name = state.desktopName;
        final connected = switch (state.status) {
          PeekDesktopLinkStatus.connected ||
          PeekDesktopLinkStatus.connecting ||
          PeekDesktopLinkStatus.waiting => true,
          _ => false,
        };
        return _SheetBody(
          title: strings.connectToDesktop,
          children: [
            PeekListSection(
              footer: state.message,
              children: [
                PeekListRow(
                  title: strings.desktopStatus,
                  leading: PeekStatusDot(_colour(theme, state.status)),
                  value: _status(strings, state),
                ),
                PeekListRow(
                  title: strings.desktopPairedWith,
                  value: name ?? strings.desktopUnpaired,
                ),
              ],
            ),
            if (connected || name != null)
              PeekListSection(
                footer: name == null ? null : strings.forgetDesktopHint,
                children: [
                  if (connected)
                    PeekListRow(
                      title: strings.disconnect,
                      titleStyle: TextStyle(color: theme.accent),
                      onTap: () => unawaited(link.disconnectDesktop()),
                    ),
                  if (name != null)
                    PeekListRow(
                      title: strings.forgetDesktop,
                      titleStyle: TextStyle(color: theme.failure),
                      onTap: () => unawaited(link.forgetDesktop()),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

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
