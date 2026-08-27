import 'dart:async';

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

/// One call in full, without a screen around it.
///
/// The same widget fills the detail pane of the wide layout and the body
/// of the pushed screen, so a call reads the same either way. A call that
/// is still running fills itself in as it goes.
///
/// Everything is on one page: what a call holds — bodies, headers,
/// cookies, the phases of its time — opens on a screen of its own rather
/// than in a tab, so the reader keeps their place.
final class PeekEntryView extends StatelessWidget {
  /// Creates the view of [entry].
  const PeekEntryView(this.entry, {super.key});

  /// The call to show.
  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return ColoredBox(
      color: theme.groupedBackground,
      child: ListView(
        children: [
          _Summary(entry: entry, strings: strings),
          SizedBox(height: theme.rowSpacing),
          _Contents(entry: entry, strings: strings),
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

/// Everything a call holds, card by card.
class _Contents extends StatelessWidget {
  const _Contents({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final elapsed = entry.duration;
    final failure = entry.failure;
    final request = entry.request;
    final response = entry.response;
    final redirects = response?.redirects ?? const [];

    return Column(
      children: [
        if (failure != null)
          PeekListSection(
            title: strings.error,
            children: [
              PeekListRow(
                leading: PeekStatusDot(theme.colorForEntry(entry)),
                title: strings.failureKind(failure.kind),
                subtitle: failure.message.isEmpty ? null : failure.message,
                chevron: true,
                onTap:
                    () => unawaited(
                      showPeekDetail(
                        context,
                        title: strings.error,
                        builder:
                            (context) => ListView(
                              padding: EdgeInsets.only(
                                top: PeekTheme.of(context).rowSpacing,
                                bottom: PeekTheme.of(context).gutter,
                              ),
                              children: [
                                PeekErrorView(
                                  failure,
                                  hasResponse: response != null,
                                  onShowResponse:
                                      response == null
                                          ? null
                                          : () => unawaited(
                                            showPeekBody(
                                              context,
                                              body: response.body,
                                              title: strings.responseBody,
                                            ),
                                          ),
                                ),
                              ],
                            ),
                      ),
                    ),
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
                      : () => unawaited(
                        _showPairs(
                          context,
                          title: strings.requestHeaders,
                          child: PeekHeadersView(request.headers),
                        ),
                      ),
            ),
            if (request.queryParameters.isNotEmpty)
              _Holds(
                icon: PeekIcons.curl,
                title: strings.queryParameters,
                value: '${request.queryParameters.length}',
                onTap:
                    () => unawaited(
                      _showPairs(
                        context,
                        title: strings.queryParameters,
                        child: PeekQueryParamsView(request.queryParameters),
                      ),
                    ),
              ),
            _Holds(
              icon: PeekIcons.cookies,
              title: strings.requestCookies,
              value: '${request.headers.cookies.length}',
              onTap:
                  request.headers.cookies.isEmpty
                      ? null
                      : () => unawaited(
                        _showPairs(
                          context,
                          title: strings.requestCookies,
                          child: PeekCookiesView(request.headers.cookies),
                        ),
                      ),
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
                      : () => unawaited(
                        _showPairs(
                          context,
                          title: strings.responseHeaders,
                          child: PeekHeadersView(response.headers),
                        ),
                      ),
            ),
            _Holds(
              icon: PeekIcons.cookies,
              title: strings.responseCookies,
              value: '${response?.headers.setCookies.length ?? 0}',
              onTap:
                  response == null || response.headers.setCookies.isEmpty
                      ? null
                      : () => unawaited(
                        _showPairs(
                          context,
                          title: strings.responseCookies,
                          child: PeekCookiesView(response.headers.setCookies),
                        ),
                      ),
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
            // How long it took is the question; when it started, when it
            // ended and where the time went are the answer, and they are a
            // screen of their own like every other part of a call.
            _Holds(
              icon: PeekIcons.timing,
              title: strings.timing,
              value: elapsed == null ? strings.none : strings.elapsed(elapsed),
              onTap:
                  () => unawaited(
                    showPeekDetail(
                      context,
                      title: strings.timing,
                      builder:
                          (context) => ListView(
                            padding: EdgeInsets.only(
                              top: PeekTheme.of(context).rowSpacing,
                              bottom: PeekTheme.of(context).gutter,
                            ),
                            children: [PeekTimingView(entry)],
                          ),
                    ),
                  ),
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

/// One thing a call holds: what it is, how much of it there is, and the way
/// to it when there is anything to see.
/// Shows one table of a call — headers, cookies — on its own screen.
Future<void> _showPairs(
  BuildContext context, {
  required String title,
  required Widget child,
}) => showPeekDetail(
  context,
  title: title,
  builder: (context) {
    final theme = PeekTheme.of(context);
    return ListView(
      padding: EdgeInsets.only(top: theme.rowSpacing, bottom: theme.gutter),
      children: [child],
    );
  },
);

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

String _bodyValue(PeekStrings strings, PeekBody body) {
  if (body is PeekEmptyBody) return strings.empty;
  if (body is PeekUnavailableBody) return strings.unavailableBody(body.reason);
  final size = body.size;
  return size == null ? strings.none : strings.bytes(size);
}
