import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_failure.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_list_row.dart';
import 'peek_list_section.dart';
import 'peek_status_dot.dart';

/// What stopped a call, in as much detail as the adapter gave.
final class PeekErrorView extends StatelessWidget {
  /// Creates a view over [failure].
  ///
  /// [onShowResponse] leads to what the server answered, for a failure
  /// that has one.
  const PeekErrorView(
    this.failure, {
    this.hasResponse = false,
    this.onShowResponse,
    super.key,
  });

  /// What went wrong.
  final PeekFailure failure;

  /// Whether the call came back with something despite failing.
  final bool hasResponse;

  /// Called to show that answer.
  final VoidCallback? onShowResponse;

  /// How many lines of a stack trace are shown before it is cut short.
  static const int traceLines = 100;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final details = failure.details;
    final trace = failure.stackTrace?.toString();

    return Column(
      children: [
        PeekListSection(
          title: strings.error,
          children: [
            PeekListRow(
              leading: PeekStatusDot(
                failure.kind == PeekFailureKind.cancelled
                    ? theme.cancelled
                    : theme.failure,
              ),
              title: strings.failureKind(failure.kind),
              subtitle: failure.message.isEmpty ? null : failure.message,
            ),
            if (hasResponse && onShowResponse != null)
              PeekListRow(
                title: strings.response,
                chevron: true,
                onTap: onShowResponse,
              ),
          ],
        ),
        if (details != null)
          _Block(
            title: strings.details,
            text: '$details',
            lineLimit: PeekErrorView.traceLines,
          ),
        if (trace != null && trace.trim().isNotEmpty)
          _Block(
            title: strings.stackTrace,
            text: trace,
            lineLimit: PeekErrorView.traceLines,
          ),
      ],
    );
  }
}

/// A block of text that keeps its shape: monospace, copyable whole, and
/// cut short before a runaway trace fills the screen.
class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.text,
    required this.lineLimit,
  });

  final String title;
  final String text;
  final int lineLimit;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final lines = text.split('\n');
    final shown =
        lines.length <= lineLimit ? text : lines.take(lineLimit).join('\n');
    final hidden = lines.length - lineLimit;

    return PeekListSection(
      title: title,
      trailing: PeekCopyButton(text: text),
      children: [
        Padding(
          padding: EdgeInsets.all(theme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(shown, style: theme.mono),
              if (hidden > 0) ...[
                SizedBox(height: theme.rowSpacing),
                Text(
                  strings.moreLines(hidden),
                  style: theme.caption.copyWith(color: theme.tertiaryLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
