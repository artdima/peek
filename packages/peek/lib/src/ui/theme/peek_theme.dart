import 'package:flutter/material.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_status_class.dart';

/// Colours, type and metrics Peek's widgets read.
///
/// Register it on the app's theme to override anything:
///
/// ```dart
/// ThemeData(extensions: [PeekTheme.light().copyWith(pending: Colors.blue)])
/// ```
///
/// Without registration [of] derives a theme from the app's own
/// `ColorScheme`, so Peek looks at home anywhere with no setup at all.
@immutable
final class PeekTheme extends ThemeExtension<PeekTheme> {
  /// Creates a theme with every value spelled out.
  const PeekTheme({
    required this.success,
    required this.redirect,
    required this.clientError,
    required this.serverError,
    required this.pending,
    required this.cancelled,
    required this.methodColors,
    required this.monoTextStyle,
    required this.surface,
    required this.rowSpacing,
    required this.gutter,
    required this.radius,
  });

  /// The light theme: the logo's green, amber and red over a paper surface.
  factory PeekTheme.light() => PeekTheme(
    success: const Color(0xFF3DDC84),
    redirect: const Color(0xFF4C8DFF),
    clientError: const Color(0xFFF2C230),
    serverError: const Color(0xFFEF4B3C),
    pending: const Color(0xFF8A8F98),
    cancelled: const Color(0xFF8A8F98),
    methodColors: _methodColors(dark: false),
    monoTextStyle: _mono(const Color(0xFF16181D)),
    surface: const Color(0xFFF6F7F9),
    rowSpacing: 8,
    gutter: 16,
    radius: 10,
  );

  /// The dark theme: the same hues, lifted for a dark surface.
  factory PeekTheme.dark() => PeekTheme(
    success: const Color(0xFF4ADE80),
    redirect: const Color(0xFF6BA5FF),
    clientError: const Color(0xFFF5D06A),
    serverError: const Color(0xFFFF6B5E),
    pending: const Color(0xFF9BA1AA),
    cancelled: const Color(0xFF9BA1AA),
    methodColors: _methodColors(dark: true),
    monoTextStyle: _mono(const Color(0xFFE6E8EB)),
    surface: const Color(0xFF16181D),
    rowSpacing: 8,
    gutter: 16,
    radius: 10,
  );

  /// The theme registered on [context], or one derived from its
  /// `ColorScheme` when none is.
  static PeekTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PeekTheme>() ?? fromColorScheme(theme.colorScheme);
  }

  /// A theme that borrows [scheme]'s error and surface colours and keeps
  /// Peek's status hues for everything a `ColorScheme` has no word for.
  static PeekTheme fromColorScheme(ColorScheme scheme) {
    final base =
        scheme.brightness == Brightness.dark
            ? PeekTheme.dark()
            : PeekTheme.light();
    return base.copyWith(
      serverError: scheme.error,
      redirect: scheme.primary,
      surface: scheme.surfaceContainerLowest,
      monoTextStyle: base.monoTextStyle.copyWith(color: scheme.onSurface),
    );
  }

  /// 2xx.
  final Color success;

  /// 3xx.
  final Color redirect;

  /// 4xx.
  final Color clientError;

  /// 5xx.
  final Color serverError;

  /// A call still in flight.
  final Color pending;

  /// A call that failed or was cancelled.
  final Color cancelled;

  /// Colour per HTTP method, keyed uppercase; unknown methods fall back to
  /// [pending].
  final Map<String, Color> methodColors;

  /// The style for URLs, headers and bodies.
  final TextStyle monoTextStyle;

  /// The background behind Peek's own surfaces.
  final Color surface;

  /// Vertical space between rows of a list.
  final double rowSpacing;

  /// Horizontal padding of Peek's screens.
  final double gutter;

  /// Corner radius of cards, chips and badges.
  final double radius;

  /// The colour standing for [statusClass].
  Color colorForStatusClass(PeekStatusClass statusClass) =>
      switch (statusClass) {
        PeekStatusClass.informational => pending,
        PeekStatusClass.success => success,
        PeekStatusClass.redirect => redirect,
        PeekStatusClass.clientError => clientError,
        PeekStatusClass.serverError => serverError,
        PeekStatusClass.unknown => pending,
      };

  /// The colour standing for [entry]: its status, or the failure that
  /// replaced it.
  Color colorForEntry(PeekEntry entry) {
    final statusClass = entry.statusClass;
    if (statusClass != null) return colorForStatusClass(statusClass);
    return entry.state == PeekEntryState.failed ? cancelled : pending;
  }

  /// The colour standing for [method], case-insensitively.
  Color colorForMethod(String method) =>
      methodColors[method.toUpperCase()] ?? pending;

  @override
  PeekTheme copyWith({
    Color? success,
    Color? redirect,
    Color? clientError,
    Color? serverError,
    Color? pending,
    Color? cancelled,
    Map<String, Color>? methodColors,
    TextStyle? monoTextStyle,
    Color? surface,
    double? rowSpacing,
    double? gutter,
    double? radius,
  }) => PeekTheme(
    success: success ?? this.success,
    redirect: redirect ?? this.redirect,
    clientError: clientError ?? this.clientError,
    serverError: serverError ?? this.serverError,
    pending: pending ?? this.pending,
    cancelled: cancelled ?? this.cancelled,
    methodColors: methodColors ?? this.methodColors,
    monoTextStyle: monoTextStyle ?? this.monoTextStyle,
    surface: surface ?? this.surface,
    rowSpacing: rowSpacing ?? this.rowSpacing,
    gutter: gutter ?? this.gutter,
    radius: radius ?? this.radius,
  );

  @override
  PeekTheme lerp(covariant PeekTheme? other, double t) {
    if (other == null) return this;
    return PeekTheme(
      success: Color.lerp(success, other.success, t)!,
      redirect: Color.lerp(redirect, other.redirect, t)!,
      clientError: Color.lerp(clientError, other.clientError, t)!,
      serverError: Color.lerp(serverError, other.serverError, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      methodColors: {
        for (final name in {...methodColors.keys, ...other.methodColors.keys})
          name:
              Color.lerp(
                methodColors[name] ?? pending,
                other.methodColors[name] ?? other.pending,
                t,
              )!,
      },
      monoTextStyle: TextStyle.lerp(monoTextStyle, other.monoTextStyle, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      rowSpacing: _lerpSize(rowSpacing, other.rowSpacing, t),
      gutter: _lerpSize(gutter, other.gutter, t),
      radius: _lerpSize(radius, other.radius, t),
    );
  }

  static double _lerpSize(double a, double b, double t) => a + (b - a) * t;

  static TextStyle _mono(Color color) => TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono', 'monospace'],
    fontSize: 13,
    height: 1.4,
    color: color,
  );

  static Map<String, Color> _methodColors({required bool dark}) => {
    'GET': dark ? const Color(0xFF6BA5FF) : const Color(0xFF4C8DFF),
    'POST': dark ? const Color(0xFF4ADE80) : const Color(0xFF3DDC84),
    'PUT': dark ? const Color(0xFFF5D06A) : const Color(0xFFF2C230),
    'PATCH': dark ? const Color(0xFFF5D06A) : const Color(0xFFF2C230),
    'DELETE': dark ? const Color(0xFFFF6B5E) : const Color(0xFFEF4B3C),
    'HEAD': dark ? const Color(0xFF9BA1AA) : const Color(0xFF8A8F98),
    'OPTIONS': dark ? const Color(0xFF9BA1AA) : const Color(0xFF8A8F98),
  };
}
