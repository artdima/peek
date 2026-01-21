/// The class of an HTTP status code: its first digit.
enum PeekStatusClass {
  /// 1xx.
  informational,

  /// 2xx.
  success,

  /// 3xx.
  redirect,

  /// 4xx.
  clientError,

  /// 5xx.
  serverError,

  /// Anything outside 100–599, such as a code a client made up.
  unknown;

  /// The class of [statusCode].
  static PeekStatusClass of(int statusCode) => switch (statusCode) {
    >= 100 && < 200 => informational,
    >= 200 && < 300 => success,
    >= 300 && < 400 => redirect,
    >= 400 && < 500 => clientError,
    >= 500 && < 600 => serverError,
    _ => unknown,
  };

  /// Whether the class means the request failed: 4xx or 5xx.
  bool get isError => this == clientError || this == serverError;
}
