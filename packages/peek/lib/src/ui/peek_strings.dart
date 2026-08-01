import 'package:flutter/foundation.dart';

import '../core/internal/formatting.dart';
import '../core/model/peek_body.dart';
import '../core/model/peek_entry.dart';
import '../core/model/peek_failure.dart';
import '../core/model/peek_status_class.dart';
import '../core/query/peek_filter.dart';
import '../core/query/peek_search_query.dart';
import '../core/query/peek_sort.dart';
import 'screens/peek_entry_tab.dart';

/// Every word Peek shows, in one place.
///
/// English by default. Subclass to translate, then hand the subclass to
/// `PeekScreen(strings: ...)`:
///
/// ```dart
/// final class PeekStringsFr extends PeekStrings {
///   const PeekStringsFr();
///   @override
///   String get search => 'Rechercher';
/// }
/// ```
@immutable
class PeekStrings {
  /// Creates the default, English strings.
  const PeekStrings();

  /// Title of the list screen.
  String get console => 'Console';

  /// Label of the search field.
  String get search => 'Search';

  /// Tooltip of the filter button.
  String get filters => 'Filters';

  /// Tooltip of the sort button.
  String get sort => 'Sort';

  /// Tooltip of the button that empties the list.
  String get clear => 'Clear';

  /// Title of the dialog that asks before emptying the list.
  String get clearTitle => 'Clear all requests?';

  /// Body of that dialog.
  String get clearMessage =>
      'This removes every recorded request, pinned '
      'ones included.';

  /// Confirms a dialog.
  String get confirm => 'Clear';

  /// Dismisses a dialog.
  String get cancel => 'Cancel';

  /// Names the area that closes a sheet when tapped.
  String get dismiss => 'Dismiss';

  /// Tooltip that pins an entry.
  String get pin => 'Pin';

  /// Tooltip that unpins an entry.
  String get unpin => 'Unpin';

  /// Shown when the pin limit is reached.
  String get pinLimitReached => 'Too many pinned requests';

  /// Shown when recording is paused.
  String get pausedBanner => 'Recording is paused';

  /// Empty state when nothing was recorded yet.
  String get noRequests => 'No requests yet';

  /// What to do about it.
  String get noRequestsHint => 'Send a request and it will show up here.';

  /// Empty state when a filter hides everything.
  String get noMatches => 'Nothing matches';

  /// What to do about that.
  String get noMatchesHint => 'Try a different search or clear the filters.';

  /// Shown on the response tab of a call still in flight.
  String get noResponse => 'No response yet';

  /// What to do about it.
  String get noResponseHint => 'The call has not come back.';

  /// Empty detail pane, before a call is picked.
  String get noSelection => 'Nothing selected';

  /// What to do about it.
  String get noSelectionHint => 'Pick a request to see it here.';

  /// Shown in place of a call that is no longer recorded.
  String get removedEntry => 'This request is gone';

  /// What happened to it.
  String get removedEntryHint => 'It was cleared from the list.';

  /// Button that clears every filter.
  String get resetFilters => 'Clear filters';

  /// Section heading for the request half.
  String get request => 'Request';

  /// Section heading for the response half.
  String get response => 'Response';

  /// How much went out.
  String get sent => 'Sent';

  /// How much came back.
  String get received => 'Received';

  /// Names the button that goes back a screen.
  String get back => 'Back';

  /// Names the button that closes a screen shown over the app.
  String get close => 'Close';

  /// Names the floating button that opens Peek.
  String get openPeek => 'Open Peek';

  /// Tab and heading for the summary.
  String get overview => 'Overview';

  /// Tab and heading for the failure.
  String get error => 'Error';

  /// Tab and heading for the phase timings.
  String get timing => 'Timing';

  /// Heading for the phases a call went through.
  String get phases => 'Phases';

  /// Heading for headers.
  String get headers => 'Headers';

  /// Heading for cookies.
  String get cookies => 'Cookies';

  /// How many headers a direction carried.
  String headerCount(int count) => 'Headers: $count';

  /// How many cookies it carried.
  String cookieCount(int count) => 'Cookies: $count';

  /// Names the cookies a request carried.
  String get requestCookies => 'Request cookies';

  /// Names the cookies a response set.
  String get responseCookies => 'Response cookies';

  /// Heading for query parameters.
  String get queryParameters => 'Query';

  /// Heading for a body.
  String get body => 'Body';

  /// Heading for the redirect chain.
  String get redirects => 'Redirects';

  /// Heading for the card that answers "what call was this".
  String get general => 'General';

  /// Label for the request body.
  String get requestBody => 'Request body';

  /// Label for the response body.
  String get responseBody => 'Response body';

  /// Label for the request headers.
  String get requestHeaders => 'Request headers';

  /// Label for the response headers.
  String get responseHeaders => 'Response headers';

  /// Label for when a call came back.
  String get finished => 'Finished';

  /// Label for the adapter that reported a call.
  String get source => 'Source';

  /// Label for when a call started.
  String get started => 'Started';

  /// Label for how long a call took.
  String get duration => 'Duration';

  /// Label for a status code.
  String get status => 'Status';

  /// Label for a method.
  String get method => 'Method';

  /// Label for a URL.
  String get url => 'URL';

  /// Label for a size.
  String get size => 'Size';

  /// Label for a stack trace.
  String get stackTrace => 'Stack trace';

  /// Heading for whatever the adapter attached to a failure.
  String get details => 'Details';

  /// Says how many lines are not shown.
  String moreLines(int count) => '$count more lines';

  /// Shown where a value is missing.
  String get none => '—';

  /// The option of a range that matches anything.
  String get any => 'Any';

  /// Shown when a section has no rows.
  String get empty => 'Empty';

  /// What to make of a body there is nothing to show for.
  String get noBodyHint => 'There is nothing to show here.';

  /// Copies a value.
  String get copy => 'Copy';

  /// Copies the URL.
  String get copyUrl => 'Copy URL';

  /// Copies a curl command.
  String get copyCurl => 'Copy as cURL';

  /// Copies every row of a table at once.
  String get copyAll => 'Copy all';

  /// Orders a table by name.
  String get sortByName => 'Sort by name';

  /// Restores a table's own order.
  String get sortByOrder => 'Keep the order sent';

  /// Says a value was masked before Peek kept it.
  String get redacted => 'Masked';

  /// Copies a plain-text summary.
  String get copyText => 'Copy as text';

  /// Copies a Markdown summary.
  String get copyMarkdown => 'Copy as Markdown';

  /// Exports an HTTP Archive.
  String get exportHar => 'Export HAR';

  /// Shares an HTTP Archive of everything the list shows.
  String get shareHar => 'Share as HAR';

  /// Names the menu of everything else a screen can do.
  String get more => 'More';

  /// Shares the exported content.
  String get share => 'Share';

  /// Confirms that something reached the clipboard.
  String get copied => 'Copied';

  /// Shows a body as it arrived.
  String get raw => 'Raw';

  /// Heading for the fields of a form.
  String get fields => 'Fields';

  /// Heading for the files of a multipart form.
  String get files => 'Files';

  /// Label for the name a file was uploaded under.
  String get filename => 'File name';

  /// Copies bytes as base64 text.
  String get copyBase64 => 'Copy as base64';

  /// The size of an image in pixels.
  String pixels(int width, int height) => '$width × $height';

  /// Says how much of a body is shown as hex.
  String firstBytes(int count) => 'First $count bytes';

  /// Shows a JSON body as a tree.
  String get tree => 'Tree';

  /// Expands every node of a tree.
  String get expandAll => 'Expand all';

  /// Says a body would not decode as JSON after all.
  String get notJson => 'This is not valid JSON';

  /// Copies the value under a node.
  String get copyValue => 'Copy value';

  /// Copies the path that leads to a node.
  String get copyPath => 'Copy path';

  /// How many values an object or an array holds.
  String items(int count) => count == 1 ? '1 item' : '$count items';

  /// Collapses every node of a tree.
  String get collapseAll => 'Collapse all';

  /// Toggles line wrapping.
  String get wrapLines => 'Wrap lines';

  /// Stops wrapping lines.
  String get stopWrapping => 'Stop wrapping';

  /// Goes to the match before this one.
  String get previousMatch => 'Previous match';

  /// Goes to the match after this one.
  String get nextMatch => 'Next match';

  /// Where the search is in what it found.
  String matchCount(int current, int total) => '$current of $total';

  /// Quick filter showing everything.
  String get all => 'All';

  /// Quick filter showing failures and 4xx/5xx.
  String get errorsOnly => 'Errors';

  /// Quick filter showing calls still in flight.
  String get pendingOnly => 'Pending';

  /// Quick filter showing pinned entries.
  String get pinnedOnly => 'Pinned';

  /// Shown while a call is in flight.
  String get pending => 'Pending';

  /// Shown when a call failed.
  String get failed => 'Failed';

  /// Heading for the host filter.
  String get host => 'Host';

  /// Heading for the content-type filter.
  String get contentType => 'Content type';

  /// Heading for the state filter.
  String get state => 'State';

  /// Name of a sort direction.
  String get newestFirst => 'Newest first';

  /// Name of a sort direction.
  String get oldestFirst => 'Oldest first';

  /// Name of a sort direction.
  String get slowestFirst => 'Slowest first';

  /// Name of a sort direction.
  String get largestFirst => 'Largest first';

  /// Names a status class as a filter option.
  String statusClassName(PeekStatusClass statusClass) => switch (statusClass) {
    PeekStatusClass.informational => '1xx',
    PeekStatusClass.success => '2xx',
    PeekStatusClass.redirect => '3xx',
    PeekStatusClass.clientError => '4xx',
    PeekStatusClass.serverError => '5xx',
    PeekStatusClass.unknown => 'Other',
  };

  /// Names a window reaching back from now.
  String recent(Duration window) =>
      window.inMinutes < 60
          ? 'Last ${window.inMinutes} min'
          : 'Last ${window.inHours} h';

  /// Names a range of durations.
  String durationFilter(PeekDurationRange range) {
    final min = range.min;
    final max = range.max;
    if (min == null && max == null) return any;
    if (min == null) return 'Under ${elapsed(max!)}';
    if (max == null) return 'Over ${elapsed(min)}';
    return '${elapsed(min)} – ${elapsed(max)}';
  }

  /// Names a range of moments.
  String dateFilter(PeekDateRange range) {
    final from = range.from;
    final to = range.to;
    if (from == null && to == null) return any;
    if (from == null) return 'Until ${clockTime(to!)}';
    if (to == null) return 'Since ${clockTime(from)}';
    return '${clockTime(from)} – ${clockTime(to)}';
  }

  /// A moment as hours and minutes on a 24-hour clock.
  String clockTime(DateTime moment) =>
      '${_twoDigits(moment.hour)}:${_twoDigits(moment.minute)}';

  /// The count shown next to the title.
  String requestCount(int shown, int total) =>
      shown == total ? '$total' : '$shown of $total';

  /// How many filters are active.
  String activeFilters(int count) => '$count active';

  /// Names the chip that drops one filter.
  String removeFilter(String label) => 'Remove $label';

  /// Announces newly arrived entries above the scroll position.
  String newRequests(int count) =>
      count == 1 ? '1 new request' : '$count new requests';

  /// A size in bytes, formatted.
  String bytes(int value) => formatBytes(value);

  /// A duration, formatted.
  String elapsed(Duration value) => formatDuration(value);

  /// Size and duration as one line; empty when neither is known.
  String metrics(Duration? duration, int? size) => [
    if (size != null && size > 0) bytes(size),
    if (duration != null) elapsed(duration),
  ].join(' · ');

  /// How a call ended, in a few words: the code with the reason the server
  /// gave, what stopped it, or that it is still running.
  String outcome(PeekEntry entry) {
    final code = entry.statusCode;
    if (code != null) {
      final reason = entry.response?.statusMessage;
      return reason == null || reason.isEmpty ? '$code' : '$code $reason';
    }
    final failure = entry.failure;
    return failure == null ? pending : failureKind(failure.kind);
  }

  /// When a call started, to the millisecond.
  String timestamp(DateTime moment) =>
      '${clockTime(moment)}:${_twoDigits(moment.second)}'
      '.${moment.millisecond.toString().padLeft(3, '0')}';

  /// Says a body was cut short.
  String truncatedBody(int shown, int total) =>
      'Showing ${formatBytes(shown)} of ${formatBytes(total)}';

  /// Says how many characters are hidden.
  String moreCharacters(int count) => '$count more characters';

  /// Describes a body Peek could not capture.
  String unavailableBody(PeekBodyUnavailableReason reason) => switch (reason) {
    PeekBodyUnavailableReason.streamed => 'Body was streamed and not kept',
    PeekBodyUnavailableReason.tooLarge => 'Body was too large to keep',
    PeekBodyUnavailableReason.notCaptured => 'Body was not captured',
    PeekBodyUnavailableReason.unreadable => 'Body could not be read',
  };

  /// Names a failure.
  String failureKind(PeekFailureKind kind) => switch (kind) {
    PeekFailureKind.timeout => 'Timed out',
    PeekFailureKind.connection => 'Connection failed',
    PeekFailureKind.badCertificate => 'Certificate rejected',
    PeekFailureKind.cancelled => 'Cancelled',
    PeekFailureKind.badResponse => 'Unexpected response',
    PeekFailureKind.unknown => 'Failed',
  };

  /// Names a lifecycle state.
  String entryState(PeekEntryState state) => switch (state) {
    PeekEntryState.pending => pending,
    PeekEntryState.completed => 'Completed',
    PeekEntryState.failed => failed,
  };

  /// Names a tab of the detail screen.
  String entryTab(PeekEntryTab tab) => switch (tab) {
    PeekEntryTab.overview => overview,
    PeekEntryTab.request => request,
    PeekEntryTab.response => response,
    PeekEntryTab.error => error,
    PeekEntryTab.timing => timing,
  };

  /// Says the adapter gave no phase timings.
  String get noBreakdown => 'This source does not report where the time went.';

  /// Names a phase of a call, given its HAR name.
  String phase(String name) => switch (name) {
    'blocked' => 'Queued',
    'dns' => 'DNS',
    'connect' => 'Connect',
    'ssl' => 'Secure',
    'send' => 'Request',
    'wait' => 'Waiting',
    'receive' => 'Download',
    _ => name,
  };

  /// Names a search scope.
  String searchScope(PeekSearchScope scope) => switch (scope) {
    PeekSearchScope.url => url,
    PeekSearchScope.headers => headers,
    PeekSearchScope.requestBody => requestBody,
    PeekSearchScope.responseBody => responseBody,
    PeekSearchScope.error => error,
  };

  /// Names a sort field and direction as a menu item.
  String sortOption(PeekSortField field, {required bool descending}) =>
      switch ((field, descending)) {
        (PeekSortField.startedAt, true) => newestFirst,
        (PeekSortField.startedAt, false) => oldestFirst,
        (PeekSortField.duration, true) => slowestFirst,
        (PeekSortField.duration, false) => 'Fastest first',
        (PeekSortField.responseSize, true) => largestFirst,
        (PeekSortField.responseSize, false) => 'Smallest first',
        (PeekSortField.requestSize, true) => 'Largest request first',
        (PeekSortField.requestSize, false) => 'Smallest request first',
        (PeekSortField.statusCode, true) => 'Highest status first',
        (PeekSortField.statusCode, false) => 'Lowest status first',
      };

  /// The semantic label read out for an entry in the list.
  String entrySemantics(PeekEntry entry) {
    final outcome = switch (entry.state) {
      PeekEntryState.pending => pending,
      PeekEntryState.completed => '$status ${entry.statusCode}',
      PeekEntryState.failed => failureKind(entry.failure!.kind),
    };
    final took = entry.duration;
    return [
      entry.request.method,
      entry.request.host,
      entry.request.path,
      outcome,
      if (took != null) elapsed(took),
      if (entry.isPinned) pinnedOnly,
    ].join(', ');
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
