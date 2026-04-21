import 'package:flutter/foundation.dart';

import '../core/internal/formatting.dart';
import '../core/model/peek_body.dart';
import '../core/model/peek_entry.dart';
import '../core/model/peek_failure.dart';
import '../core/model/peek_status_class.dart';
import '../core/query/peek_filter.dart';
import '../core/query/peek_search_query.dart';
import '../core/query/peek_sort.dart';

/// Every word Peek shows, in one place.
///
/// English by default. Subclass to translate, then hand the subclass to
/// `PeekScreen(strings: ...)`:
///
/// ```dart
/// final class PeekStringsFr extends PeekStrings {
///   const PeekStringsFr();
///   @override
///   String get requests => 'Requêtes';
/// }
/// ```
@immutable
class PeekStrings {
  /// Creates the default, English strings.
  const PeekStrings();

  /// Title of the list screen.
  String get requests => 'Requests';

  /// Label of the search field.
  String get search => 'Search';

  /// Tooltip of the button that empties the search field.
  String get clearSearch => 'Clear search';

  /// Tooltip of the filter button.
  String get filters => 'Filters';

  /// Tooltip of the sort button.
  String get sort => 'Sort';

  /// Tooltip that stops recording.
  String get pause => 'Pause recording';

  /// Tooltip that resumes recording.
  String get resume => 'Resume recording';

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

  /// Tab and heading for the summary.
  String get overview => 'Overview';

  /// Tab and heading for the failure.
  String get error => 'Error';

  /// Tab and heading for the phase timings.
  String get timing => 'Timing';

  /// Heading for headers.
  String get headers => 'Headers';

  /// Heading for cookies.
  String get cookies => 'Cookies';

  /// Heading for query parameters.
  String get queryParameters => 'Query';

  /// Heading for a body.
  String get body => 'Body';

  /// Heading for the redirect chain.
  String get redirects => 'Redirects';

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

  /// Shown where a value is missing.
  String get none => '—';

  /// The option of a range that matches anything.
  String get any => 'Any';

  /// Shown when a section has no rows.
  String get empty => 'Empty';

  /// Copies a value.
  String get copy => 'Copy';

  /// Copies the URL.
  String get copyUrl => 'Copy URL';

  /// Copies a curl command.
  String get copyCurl => 'Copy as cURL';

  /// Copies a plain-text summary.
  String get copyText => 'Copy as text';

  /// Copies a Markdown summary.
  String get copyMarkdown => 'Copy as Markdown';

  /// Exports an HTTP Archive.
  String get exportHar => 'Export HAR';

  /// Shares the exported content.
  String get share => 'Share';

  /// Confirms that something reached the clipboard.
  String get copied => 'Copied';

  /// Shows a body as it arrived.
  String get raw => 'Raw';

  /// Shows a JSON body as a tree.
  String get tree => 'Tree';

  /// Expands every node of a tree.
  String get expandAll => 'Expand all';

  /// Collapses every node of a tree.
  String get collapseAll => 'Collapse all';

  /// Toggles line wrapping.
  String get wrapLines => 'Wrap lines';

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

  /// Names a search scope.
  String searchScope(PeekSearchScope scope) => switch (scope) {
    PeekSearchScope.url => url,
    PeekSearchScope.headers => headers,
    PeekSearchScope.requestBody => 'Request body',
    PeekSearchScope.responseBody => 'Response body',
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
