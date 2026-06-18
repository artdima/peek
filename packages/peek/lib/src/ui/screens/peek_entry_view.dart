import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_body.dart';
import '../../core/model/peek_entry.dart';
import '../../core/model/peek_status_class.dart';
import '../icons/icons.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';
import 'peek_entry_screen.dart';
import 'peek_entry_tab.dart';

/// One call in full, without a screen around it.
///
/// The same widget fills the detail pane of the wide layout and the body
/// of the pushed screen, so a call reads the same either way. A call that
/// is still running fills itself in as it goes: the tabs it can offer
/// follow what it has.
final class PeekEntryView extends StatefulWidget {
  /// Creates the view of [entry], opened on [initialTab].
  const PeekEntryView(
    this.entry, {
    this.initialTab = PeekEntryTab.overview,
    super.key,
  });

  /// The call to show.
  final PeekEntry entry;

  /// Which tab to open on.
  final PeekEntryTab initialTab;

  @override
  State<PeekEntryView> createState() => _PeekEntryViewState();
}

class _PeekEntryViewState extends State<PeekEntryView> {
  late PeekEntryTab _tab = widget.initialTab;

  /// The tabs this call has something to say on.
  List<PeekEntryTab> get _tabs => [
    PeekEntryTab.overview,
    PeekEntryTab.request,
    PeekEntryTab.response,
    if (widget.entry.failure != null) PeekEntryTab.error,
    if (widget.entry.timings != null) PeekEntryTab.timing,
  ];

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final tabs = _tabs;
    // A tab can go away — a failure that a retry replaced, say — and the
    // view must not keep showing an empty one.
    final tab = tabs.contains(_tab) ? _tab : PeekEntryTab.overview;

    return ColoredBox(
      color: theme.groupedBackground,
      child: ListView(
        children: [
          _Summary(entry: widget.entry, strings: strings),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.gutter),
            child: PeekSegmented<PeekEntryTab>(
              selected: tab,
              onChanged: (value) => setState(() => _tab = value),
              segments: [
                for (final value in tabs)
                  PeekSegment(value: value, label: strings.entryTab(value)),
              ],
            ),
          ),
          SizedBox(height: theme.rowSpacing),
          switch (tab) {
            PeekEntryTab.overview => _Overview(
              entry: widget.entry,
              strings: strings,
              onShowTab: (value) => setState(() => _tab = value),
            ),
            PeekEntryTab.request => _Request(
              entry: widget.entry,
              strings: strings,
            ),
            PeekEntryTab.response => _Response(
              entry: widget.entry,
              strings: strings,
            ),
            PeekEntryTab.error => PeekErrorView(
              widget.entry.failure!,
              hasResponse: widget.entry.response != null,
              onShowResponse:
                  () => setState(() => _tab = PeekEntryTab.response),
            ),
            PeekEntryTab.timing => PeekTimingView(widget.entry),
          },
        ],
      ),
    );
  }
}

/// The head of the screen: how much moved, how it went, what was asked.
///
/// The amounts lead, the way Pulse leads with them: a reader glances at a
/// call's weight before reading its address.
class _Summary extends StatelessWidget {
  const _Summary({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final elapsed = entry.duration;
    final outcome = theme.colorForEntry(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Transfer(entry: entry, strings: strings),
        PeekListSection(
          children: [
            PeekListRow(
              // A tick means it came back as asked; anything else keeps the
              // dot the list uses, since a tick would be a lie.
              leading:
                  entry.statusClass == PeekStatusClass.success
                      ? PeekIcon(
                        PeekIcons.ok,
                        color: outcome,
                        knockout: theme.card,
                      )
                      : PeekStatusDot(outcome),
              title: strings.outcome(entry),
              titleStyle: TextStyle(
                color: outcome,
                fontWeight: FontWeight.w600,
              ),
              value: elapsed == null ? null : strings.elapsed(elapsed),
            ),
            _Address(entry: entry),
          ],
        ),
      ],
    );
  }
}

/// What went out and what came back, side by side.
class _Transfer extends StatelessWidget {
  const _Transfer({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final response = entry.response;

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 6, theme.gutter, theme.gutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Amount(
                icon: PeekIcons.sent,
                label: strings.sent,
                bytes: entry.requestSize,
                headers: entry.request.headers.length,
                cookies: entry.request.headers.cookies.length,
                strings: strings,
              ),
            ),
            SizedBox(
              width: theme.hairline,
              child: ColoredBox(
                color: theme.separator,
                child: const SizedBox(height: double.infinity),
              ),
            ),
            Expanded(
              child: _Amount(
                icon: PeekIcons.received,
                label: strings.received,
                bytes: entry.responseSize,
                headers: response?.headers.length ?? 0,
                cookies: response?.headers.setCookies.length ?? 0,
                strings: strings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One direction: its arrow, its weight, and what carried it.
class _Amount extends StatelessWidget {
  const _Amount({
    required this.icon,
    required this.label,
    required this.bytes,
    required this.headers,
    required this.cookies,
    required this.strings,
  });

  final PeekIconData icon;
  final String label;
  final int? bytes;
  final int headers;
  final int cookies;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final size = bytes;
    final quiet = theme.caption.copyWith(color: theme.secondaryLabel);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PeekIcon(icon, size: 28, color: theme.label),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.headline,
                  ),
                  Text(
                    size == null ? strings.none : strings.bytes(size),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.headline.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          strings.headerCount(headers),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: quiet,
        ),
        Text(
          strings.cookieCount(cookies),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: quiet,
        ),
      ],
    );
  }
}

/// The method and the address, as one line to read and one to copy.
class _Address extends StatelessWidget {
  const _Address({required this.entry});

  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final url = entry.request.uri.toString();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.gutter, vertical: 14),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.request.method.toUpperCase()} ',
              style: theme.body.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: url),
          ],
        ),
        style: theme.body,
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.entry,
    required this.strings,
    required this.onShowTab,
  });

  final PeekEntry entry;
  final PeekStrings strings;
  final ValueChanged<PeekEntryTab> onShowTab;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final elapsed = entry.duration;
    final finishedAt = entry.completedAt;
    final failure = entry.failure;
    final request = entry.request;
    final response = entry.response;
    final redirects = response?.redirects ?? const [];

    return Column(
      children: [
        PeekListSection(
          title: strings.general,
          children: [
            PeekListRow(title: strings.host, value: entry.request.host),
            PeekListRow(
              title: strings.started,
              value: strings.timestamp(entry.startedAt),
            ),
            PeekListRow(
              title: strings.finished,
              value:
                  finishedAt == null
                      ? strings.none
                      : strings.timestamp(finishedAt),
            ),
          ],
        ),
        if (failure != null)
          PeekListSection(
            title: strings.error,
            children: [
              PeekListRow(
                leading: PeekStatusDot(theme.colorForEntry(entry)),
                title: strings.failureKind(failure.kind),
                subtitle: failure.message.isEmpty ? null : failure.message,
                chevron: true,
                onTap: () => onShowTab(PeekEntryTab.error),
              ),
            ],
          ),
        PeekListSection(
          title: strings.request,
          children: [
            _Holds(
              icon: PeekIcons.sent,
              title: strings.requestBody,
              value: _bodyValue(strings, request.body),
              onTap:
                  request.body is PeekEmptyBody
                      ? null
                      : () => unawaited(
                        showPeekBody(
                          context,
                          body: request.body,
                          title: strings.requestBody,
                        ),
                      ),
            ),
            _Holds(
              icon: PeekIcons.headers,
              title: strings.requestHeaders,
              value: '${request.headers.length}',
              onTap:
                  request.headers.length == 0
                      ? null
                      : () => onShowTab(PeekEntryTab.request),
            ),
            _Holds(
              icon: PeekIcons.cookies,
              title: strings.requestCookies,
              value: '${request.headers.cookies.length}',
              onTap:
                  request.headers.cookies.isEmpty
                      ? null
                      : () => onShowTab(PeekEntryTab.request),
            ),
          ],
        ),
        PeekListSection(
          title: strings.response,
          children: [
            _Holds(
              icon: PeekIcons.received,
              title: strings.responseBody,
              value:
                  response == null
                      ? strings.none
                      : _bodyValue(strings, response.body),
              onTap:
                  response == null || response.body is PeekEmptyBody
                      ? null
                      : () => unawaited(
                        showPeekBody(
                          context,
                          body: response.body,
                          title: strings.responseBody,
                        ),
                      ),
            ),
            _Holds(
              icon: PeekIcons.headers,
              title: strings.responseHeaders,
              value: '${response?.headers.length ?? 0}',
              onTap:
                  response == null || response.headers.length == 0
                      ? null
                      : () => onShowTab(PeekEntryTab.response),
            ),
            _Holds(
              icon: PeekIcons.cookies,
              title: strings.responseCookies,
              value: '${response?.headers.setCookies.length ?? 0}',
              onTap:
                  response == null || response.headers.setCookies.isEmpty
                      ? null
                      : () => onShowTab(PeekEntryTab.response),
            ),
          ],
        ),
        if (redirects.isNotEmpty)
          PeekListSection(
            title: strings.redirects,
            children: [
              for (final hop in redirects)
                PeekListRow(
                  title: '${hop.statusCode} ${hop.method}',
                  subtitle: hop.location.toString(),
                ),
            ],
          ),
        PeekListSection(
          title: strings.details,
          children: [
            _Holds(
              icon: PeekIcons.timing,
              title: strings.timing,
              value: elapsed == null ? strings.none : strings.elapsed(elapsed),
              onTap: () => onShowTab(PeekEntryTab.timing),
            ),
            _Holds(
              icon: PeekIcons.source,
              title: strings.source,
              value: entry.source,
            ),
          ],
        ),
      ],
    );
  }
}

/// One plain fact of a call, marked the way the rows around it are.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, required this.value});

  final PeekIconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => PeekListRow(
    leading: PeekIcon(icon, color: PeekTheme.of(context).accent),
    title: title,
    value: value,
  );
}

/// One thing a call holds: what it is, how much of it there is, and the way
/// to it when there is anything to see.
class _Holds extends StatelessWidget {
  const _Holds({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final PeekIconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final leads = onTap != null;

    return PeekListRow(
      leading: PeekIcon(
        icon,
        color: leads ? theme.accent : theme.tertiaryLabel,
      ),
      title: title,
      value: value,
      // Kept even where the row leads nowhere: without it the values of a
      // card would not line up.
      chevron: true,
      enabled: leads,
      onTap: onTap,
    );
  }
}

class _Request extends StatelessWidget {
  const _Request({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final request = entry.request;
    final query = request.queryParameters;
    final cookies = request.headers.cookies;

    return Column(
      children: [
        PeekListSection(
          title: strings.request,
          children: [
            _Fact(
              icon: PeekIcons.curl,
              title: strings.method,
              value: request.method,
            ),
            _Fact(
              icon: PeekIcons.source,
              title: strings.host,
              value: request.host,
            ),
            _Fact(
              icon: PeekIcons.headers,
              title: strings.contentType,
              value: request.mediaType?.mimeType ?? strings.none,
            ),
            _BodyRow(
              body: request.body,
              title: strings.requestBody,
              icon: PeekIcons.sent,
              strings: strings,
            ),
          ],
        ),
        if (query.isNotEmpty) PeekQueryParamsView(query),
        PeekHeadersView(request.headers),
        if (cookies.isNotEmpty) PeekCookiesView(cookies),
      ],
    );
  }
}

class _Response extends StatelessWidget {
  const _Response({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final response = entry.response;
    if (response == null) {
      return PeekEmptyState(
        title: strings.noResponse,
        message: strings.noResponseHint,
        icon: Icons.hourglass_empty,
      );
    }
    final cookies = response.headers.setCookies;

    return Column(
      children: [
        PeekListSection(
          title: strings.response,
          children: [
            _Fact(
              icon: PeekIcons.headers,
              title: strings.contentType,
              value: response.mediaType?.mimeType ?? strings.none,
            ),
            _BodyRow(
              body: response.body,
              title: strings.responseBody,
              icon: PeekIcons.received,
              strings: strings,
            ),
          ],
        ),
        PeekHeadersView(response.headers),
        if (cookies.isNotEmpty) PeekCookiesView(cookies),
      ],
    );
  }
}

/// The row that leads to a body, and says how much of one there is.
class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.body,
    required this.title,
    required this.icon,
    required this.strings,
  });

  final PeekBody body;
  final String title;
  final PeekIconData icon;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final nothing = body is PeekEmptyBody;

    return PeekListRow(
      leading: PeekIcon(
        icon,
        color: nothing ? theme.tertiaryLabel : theme.accent,
      ),
      title: title,
      value: _bodyValue(strings, body),
      chevron: true,
      enabled: !nothing,
      onTap: () => unawaited(showPeekBody(context, body: body, title: title)),
    );
  }
}

String _bodyValue(PeekStrings strings, PeekBody body) {
  if (body is PeekEmptyBody) return strings.empty;
  if (body is PeekUnavailableBody) return strings.unavailableBody(body.reason);
  final size = body.size;
  return size == null ? strings.none : strings.bytes(size);
}
