import 'package:meta/meta.dart';

import 'peek_media_type.dart';

/// One `name=value` field of a form body.
@immutable
final class PeekFormField {
  /// Creates a field.
  const PeekFormField(this.name, this.value);

  /// The field name.
  final String name;

  /// The field value, decoded.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is PeekFormField && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => 'PeekFormField($name)';
}

/// One file part of a multipart body. Only metadata is kept: file contents
/// are never captured.
@immutable
final class PeekFormFile {
  /// Creates a file part.
  const PeekFormFile(this.name, {this.filename, this.contentType, this.size});

  /// The part name.
  final String name;

  /// The file name sent with the part, when any.
  final String? filename;

  /// The declared media type of the part, when any.
  final PeekMediaType? contentType;

  /// The size of the part in bytes, when known.
  final int? size;

  @override
  bool operator ==(Object other) =>
      other is PeekFormFile &&
      other.name == name &&
      other.filename == filename &&
      other.contentType == contentType &&
      other.size == size;

  @override
  int get hashCode => Object.hash(name, filename, contentType, size);

  @override
  String toString() => 'PeekFormFile($name, ${filename ?? '-'})';
}
