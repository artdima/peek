import 'dart:async';

import 'package:flutter/material.dart' show Icons, SelectableText;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_body.dart';
import '../../core/model/peek_entry.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(
            child: ListView(
              children: [
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
          ),
        ],
      ),
    );
  }
}

/// The head of the screen: what was asked, how it went, how much moved.
class _Summary extends StatelessWidget {
  const _Summary({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final theme = PeekTheme.of(context);
    final url = entry.request.uri.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.request.method.toUpperCase(),
                    style: theme.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: PeekStatusLabel(entry)),
                  PeekIconButton(
                    icon:
                        entry.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                    tooltip: entry.isPinned ? strings.unpin : strings.pin,
                    size: 18,
                    onPressed: () => controller.togglePin(entry.id),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SelectableText(url, style: theme.body)),
                  PeekCopyButton(text: url),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: theme.rowSpacing),
        _Transfer(entry: entry, strings: strings),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, theme.gutter),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Amount(
                icon: Icons.arrow_upward,
                label: strings.sent,
                bytes: entry.requestSize,
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
                icon: Icons.arrow_downward,
                label: strings.received,
                bytes: entry.responseSize,
                strings: strings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.icon,
    required this.label,
    required this.bytes,
    required this.strings,
  });

  final IconData icon;
  final String label;
  final int? bytes;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final size = bytes;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: theme.secondaryLabel),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.footnote.copyWith(color: theme.secondaryLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          size == null ? strings.none : strings.bytes(size),
          style: theme.headline,
        ),
      ],
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
    final redirects = entry.response?.redirects ?? const [];

    return Column(
      children: [
        PeekListSection(
          title: strings.general,
          children: [
            PeekListRow(title: strings.method, value: entry.request.method),
            PeekListRow(title: strings.status, value: strings.outcome(entry)),
            PeekListRow(title: strings.host, value: entry.request.host),
            PeekListRow(
              title: strings.duration,
              value: elapsed == null ? strings.none : strings.elapsed(elapsed),
            ),
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
          title: strings.sizes,
          children: [
            PeekListRow(
              title: strings.requestBody,
              value: _bodyValue(strings, entry.request.body),
            ),
            PeekListRow(
              title: strings.responseBody,
              value:
                  entry.response == null
                      ? strings.none
                      : _bodyValue(strings, entry.response!.body),
            ),
            PeekListRow(
              title: strings.requestHeaders,
              value: '${entry.request.headers.length}',
            ),
            PeekListRow(
              title: strings.responseHeaders,
              value: '${entry.response?.headers.length ?? 0}',
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
          title: strings.source,
          children: [PeekListRow(title: strings.source, value: entry.source)],
        ),
      ],
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
            PeekListRow(title: strings.method, value: request.method),
            PeekListRow(title: strings.host, value: request.host),
            PeekListRow(
              title: strings.contentType,
              value: request.mediaType?.mimeType ?? strings.none,
            ),
            _BodyRow(
              body: request.body,
              title: strings.requestBody,
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
            PeekListRow(title: strings.status, value: strings.outcome(entry)),
            PeekListRow(
              title: strings.contentType,
              value: response.mediaType?.mimeType ?? strings.none,
            ),
            _BodyRow(
              body: response.body,
              title: strings.responseBody,
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
    required this.strings,
  });

  final PeekBody body;
  final String title;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final nothing = body is PeekEmptyBody;
    return PeekListRow(
      title: title,
      value: _bodyValue(strings, body),
      chevron: !nothing,
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
