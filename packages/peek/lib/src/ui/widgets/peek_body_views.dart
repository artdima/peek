import 'dart:convert';

import 'package:flutter/material.dart' show Icons, SelectableText;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_body.dart';
import '../../core/model/peek_form_data.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_empty_state.dart';
import 'peek_json_tree_view.dart';
import 'peek_key_value_row.dart';
import 'peek_key_values_view.dart';
import 'peek_list_section.dart';
import 'peek_text_body_view.dart';

/// A body, shown the way its kind deserves.
///
/// The content type decides: JSON becomes a tree, other text becomes
/// numbered lines, an image is drawn, a form is a table, and bytes Peek
/// cannot read are shown as what they are.
final class PeekBodyView extends StatelessWidget {
  /// Creates a view over [body].
  const PeekBodyView(this.body, {super.key});

  /// What to show.
  final PeekBody body;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);

    return switch (body) {
      PeekEmptyBody() => PeekEmptyState(
        title: strings.empty,
        message: strings.noBodyHint,
      ),
      PeekUnavailableBody(:final reason) => PeekEmptyState(
        title: strings.unavailableBody(reason),
        message: strings.noBodyHint,
        icon: Icons.visibility_off_outlined,
      ),
      final PeekTextBody text when text.contentType?.isJson ?? false =>
        PeekJsonTreeView(
          source: text.text,
          capturedSize: text.capturedSize,
          totalSize: text.size,
        ),
      final PeekTextBody text => PeekTextBodyView(
        text: text.text,
        capturedSize: text.capturedSize,
        totalSize: text.size,
      ),
      final PeekFormBody form => PeekFormBodyView(form),
      final PeekBytesBody bytes when bytes.contentType?.isImage ?? false =>
        PeekImageBodyView(bytes),
      final PeekBytesBody bytes => PeekBinaryBodyView(bytes),
    };
  }
}

/// The fields and files of a form.
final class PeekFormBodyView extends StatelessWidget {
  /// Creates a view over [body].
  const PeekFormBodyView(this.body, {super.key});

  /// What to show.
  final PeekFormBody body;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);

    return ListView(
      children: [
        PeekKeyValuesView(
          title: strings.fields,
          pairs: [
            for (final field in body.fields)
              PeekKeyValue(field.name, field.value),
          ],
        ),
        if (body.files.isNotEmpty)
          PeekListSection(
            title: strings.files,
            children: [for (final file in body.files) _FileRow(file: file)],
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final PeekFormFile file;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final size = file.size;

    return PeekKeyValueRow(
      name: file.name,
      value: file.filename ?? strings.none,
      subtitle: [
        if (file.contentType case final type?) type.mimeType,
        if (size != null) strings.bytes(size),
      ].join(' · '),
    );
  }
}

/// An image body, drawn and measurable.
final class PeekImageBodyView extends StatelessWidget {
  /// Creates a view over [body].
  const PeekImageBodyView(this.body, {super.key});

  /// What to show.
  final PeekBytesBody body;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return ListView(
      padding: EdgeInsets.all(theme.gutter),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.radius),
          child: Container(
            height: 260,
            color: theme.card,
            child: InteractiveViewer(
              maxScale: 8,
              child: Image.memory(
                body.bytes,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stack) => Padding(
                      padding: EdgeInsets.all(theme.gutter),
                      child: Text(
                        strings.unavailableBody(
                          PeekBodyUnavailableReason.unreadable,
                        ),
                        style: theme.footnote.copyWith(color: theme.failure),
                      ),
                    ),
              ),
            ),
          ),
        ),
        SizedBox(height: theme.rowSpacing),
        Text(
          [
            if (body.contentType case final type?) type.mimeType,
            strings.bytes(body.size),
          ].join(' · '),
          textAlign: TextAlign.center,
          style: theme.footnote.copyWith(color: theme.secondaryLabel),
        ),
      ],
    );
  }
}

/// Bytes Peek cannot show as anything else.
final class PeekBinaryBodyView extends StatelessWidget {
  /// Creates a view over [body].
  const PeekBinaryBodyView(this.body, {super.key});

  /// What to show.
  final PeekBytesBody body;

  /// How many bytes the hex preview shows.
  static const int previewBytes = 512;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final shown = body.bytes.take(previewBytes).toList();

    return ListView(
      children: [
        PeekListSection(
          title: strings.body,
          trailing: PeekCopyButton(
            text: base64Encode(body.bytes),
            tooltip: strings.copyBase64,
          ),
          children: [
            PeekKeyValueRow(
              name: strings.contentType,
              value: body.contentType?.mimeType ?? strings.none,
            ),
            PeekKeyValueRow(
              name: strings.size,
              value: strings.bytes(body.size),
            ),
          ],
        ),
        PeekListSection(
          title: strings.firstBytes(shown.length),
          children: [
            Padding(
              padding: EdgeInsets.all(theme.gutter),
              child: SelectableText(
                _hex(shown),
                style: theme.mono.copyWith(color: theme.secondaryLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _hex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final (index, byte) in bytes.indexed) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
      buffer.write((index + 1) % 16 == 0 ? '\n' : ' ');
    }
    return buffer.toString().trimRight();
  }
}
