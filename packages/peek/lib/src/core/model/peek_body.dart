import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';
import '../internal/utf8.dart';
import 'peek_form_data.dart';
import 'peek_media_type.dart';

/// Why a body exists but was not captured.
enum PeekBodyUnavailableReason {
  /// The body was a stream that was never buffered.
  streamed,

  /// The body exceeded the capture limit.
  tooLarge,

  /// The source never handed the body over.
  notCaptured,

  /// The body could not be read or decoded.
  unreadable,
}

/// The body of a request or response — as much of it as Peek could capture.
///
/// Match on the subtypes to render it: [PeekTextBody], [PeekBytesBody],
/// [PeekFormBody], [PeekEmptyBody] and [PeekUnavailableBody].
@immutable
sealed class PeekBody {
  const PeekBody();

  /// No body at all.
  const factory PeekBody.empty() = PeekEmptyBody;

  /// A textual body. Pass [size] when [text] is only a prefix of the full
  /// body; it defaults to the encoded size of [text].
  factory PeekBody.text(String text, {PeekMediaType? contentType, int? size}) =
      PeekTextBody;

  /// A binary body. [bytes] are copied; pass [size] when they are only a
  /// prefix of the full body.
  factory PeekBody.bytes(
    Uint8List bytes, {
    PeekMediaType? contentType,
    int? size,
  }) = PeekBytesBody;

  /// A form body: URL-encoded fields, or multipart fields and files.
  factory PeekBody.form({
    List<PeekFormField> fields,
    List<PeekFormFile> files,
    PeekMediaType? contentType,
  }) = PeekFormBody;

  /// A body that exists but was not captured, for the given [reason].
  const factory PeekBody.unavailable(
    PeekBodyUnavailableReason reason, {
    PeekMediaType? contentType,
    int? size,
  }) = PeekUnavailableBody;

  /// Encodes an already decoded JSON value — the `data` of a Dio response,
  /// say — as compact JSON text. `null` becomes [PeekBody.empty]; values JSON
  /// cannot represent are written through `toString`.
  factory PeekBody.fromJsonLike(Object? value, {PeekMediaType? contentType}) {
    if (value == null) return const PeekBody.empty();
    return PeekBody.text(
      jsonEncode(value, toEncodable: (object) => object.toString()),
      contentType: contentType ?? PeekMediaType.json,
    );
  }

  /// The declared media type, when known.
  PeekMediaType? get contentType;

  /// The full size of the body in bytes, when known.
  int? get size;

  /// Whether Peek holds fewer bytes than the body had.
  bool get isTruncated;

  /// Whether there is nothing in the body.
  bool get isEmpty;
}

/// A body held as text.
final class PeekTextBody extends PeekBody {
  /// See [PeekBody.text].
  factory PeekTextBody(String text, {PeekMediaType? contentType, int? size}) {
    final captured = utf8Length(text);
    return PeekTextBody._(
      text,
      contentType: contentType,
      capturedSize: captured,
      size: size == null || size < captured ? captured : size,
    );
  }

  const PeekTextBody._(
    this.text, {
    required this.contentType,
    required this.capturedSize,
    required this.size,
  });

  /// The captured text, possibly a prefix of the full body.
  final String text;

  /// The size of [text] in bytes once UTF-8 encoded.
  final int capturedSize;

  @override
  final PeekMediaType? contentType;

  @override
  final int size;

  @override
  bool get isTruncated => size > capturedSize;

  @override
  bool get isEmpty => text.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is PeekTextBody &&
      other.text == text &&
      other.size == size &&
      other.contentType == contentType;

  @override
  int get hashCode => Object.hash(text, size, contentType);

  @override
  String toString() => 'PeekTextBody($size B, ${contentType ?? '-'})';
}

/// A body held as raw bytes.
final class PeekBytesBody extends PeekBody {
  /// See [PeekBody.bytes].
  factory PeekBytesBody(
    Uint8List bytes, {
    PeekMediaType? contentType,
    int? size,
  }) {
    final copy = Uint8List.fromList(bytes).asUnmodifiableView();
    return PeekBytesBody._(
      copy,
      contentType: contentType,
      size: size == null || size < copy.length ? copy.length : size,
    );
  }

  const PeekBytesBody._(
    this.bytes, {
    required this.contentType,
    required this.size,
  });

  /// The captured bytes, possibly a prefix of the full body.
  final Uint8List bytes;

  @override
  final PeekMediaType? contentType;

  @override
  final int size;

  @override
  bool get isTruncated => size > bytes.length;

  @override
  bool get isEmpty => bytes.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is PeekBytesBody &&
      other.size == size &&
      other.contentType == contentType &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(bytes.length, size, contentType);

  @override
  String toString() => 'PeekBytesBody($size B, ${contentType ?? '-'})';
}

/// A form body: URL-encoded fields, or multipart fields and files.
final class PeekFormBody extends PeekBody {
  /// See [PeekBody.form].
  PeekFormBody({
    List<PeekFormField> fields = const [],
    List<PeekFormFile> files = const [],
    this.contentType,
  }) : fields = List.unmodifiable(fields),
       files = List.unmodifiable(files);

  /// The plain fields, in order.
  final List<PeekFormField> fields;

  /// The file parts, in order.
  final List<PeekFormFile> files;

  @override
  final PeekMediaType? contentType;

  /// Unknown: the encoded form was never seen.
  @override
  int? get size => null;

  @override
  bool get isTruncated => false;

  @override
  bool get isEmpty => fields.isEmpty && files.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is PeekFormBody &&
      other.contentType == contentType &&
      listEquals(other.fields, fields) &&
      listEquals(other.files, files);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(fields), Object.hashAll(files), contentType);

  @override
  String toString() =>
      'PeekFormBody(${fields.length} fields, ${files.length} files)';
}

/// No body at all.
final class PeekEmptyBody extends PeekBody {
  /// See [PeekBody.empty].
  const PeekEmptyBody();

  @override
  PeekMediaType? get contentType => null;

  @override
  int get size => 0;

  @override
  bool get isTruncated => false;

  @override
  bool get isEmpty => true;

  @override
  bool operator ==(Object other) => other is PeekEmptyBody;

  @override
  int get hashCode => (PeekEmptyBody).hashCode;

  @override
  String toString() => 'PeekEmptyBody()';
}

/// A body that exists but was not captured.
final class PeekUnavailableBody extends PeekBody {
  /// See [PeekBody.unavailable].
  const PeekUnavailableBody(this.reason, {this.contentType, this.size});

  /// Why the body is missing.
  final PeekBodyUnavailableReason reason;

  @override
  final PeekMediaType? contentType;

  @override
  final int? size;

  @override
  bool get isTruncated => false;

  @override
  bool get isEmpty => false;

  @override
  bool operator ==(Object other) =>
      other is PeekUnavailableBody &&
      other.reason == reason &&
      other.contentType == contentType &&
      other.size == size;

  @override
  int get hashCode => Object.hash(reason, contentType, size);

  @override
  String toString() => 'PeekUnavailableBody(${reason.name})';
}
