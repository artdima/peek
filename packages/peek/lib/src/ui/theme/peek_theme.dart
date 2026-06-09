import 'package:flutter/material.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_failure.dart';
import '../../core/model/peek_status_class.dart';

/// Every colour, type style and measurement Peek draws with.
///
/// Peek brings its own look rather than borrowing the app's: a network log
/// should read the same wherever it is embedded. Register an override on
/// the app's theme to change any of it:
///
/// ```dart
/// ThemeData(extensions: [PeekTheme.light().copyWith(accent: Colors.teal)])
/// ```
@immutable
final class PeekTheme extends ThemeExtension<PeekTheme> {
  /// Creates a theme with every token spelled out.
  const PeekTheme({
    required this.background,
    required this.groupedBackground,
    required this.card,
    required this.fill,
    required this.separator,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.accent,
    required this.success,
    required this.redirect,
    required this.clientError,
    required this.serverError,
    required this.pending,
    required this.cancelled,
    required this.failure,
    required this.highlight,
    required this.methodColors,
    required this.largeTitle,
    required this.headline,
    required this.body,
    required this.footnote,
    required this.caption,
    required this.mono,
    required this.gutter,
    required this.rowSpacing,
    required this.radius,
    required this.hairline,
    required this.minRowHeight,
    required this.minTapTarget,
  });

  /// The light theme: ink on paper, with the status hues carrying meaning.
  factory PeekTheme.light() => PeekTheme(
    background: const Color(0xFFFFFFFF),
    groupedBackground: const Color(0xFFF2F2F7),
    card: const Color(0xFFFFFFFF),
    fill: const Color(0xFFEFEFF0),
    separator: const Color(0xFFD3D3D7),
    label: const Color(0xFF000000),
    secondaryLabel: const Color(0xFF6A6A6F),
    tertiaryLabel: const Color(0xFF9A9AA0),
    accent: const Color(0xFF007AFF),
    success: const Color(0xFF0F9D58),
    redirect: const Color(0xFF0A6FD8),
    clientError: const Color(0xFFB26A00),
    serverError: const Color(0xFFD70015),
    pending: const Color(0xFF6A6A6F),
    cancelled: const Color(0xFF6A6A6F),
    failure: const Color(0xFFD70015),
    highlight: const Color(0xFFFFE9A8),
    methodColors: _methodColors(dark: false),
    largeTitle: _largeTitle.copyWith(color: const Color(0xFF000000)),
    headline: _headline.copyWith(color: const Color(0xFF000000)),
    body: _body.copyWith(color: const Color(0xFF000000)),
    footnote: _footnote.copyWith(color: const Color(0xFF6A6A6F)),
    caption: _caption.copyWith(color: const Color(0xFF6A6A6F)),
    mono: _mono.copyWith(color: const Color(0xFF000000)),
    gutter: 16,
    rowSpacing: 8,
    radius: 10,
    hairline: 0.5,
    minRowHeight: 44,
    minTapTarget: 48,
  );

  /// The dark theme: the same structure on black, hues lifted to match.
  factory PeekTheme.dark() => PeekTheme(
    background: const Color(0xFF000000),
    groupedBackground: const Color(0xFF000000),
    card: const Color(0xFF1C1C1E),
    fill: const Color(0xFF2C2C2E),
    separator: const Color(0xFF38383A),
    label: const Color(0xFFFFFFFF),
    secondaryLabel: const Color(0xFF98989D),
    tertiaryLabel: const Color(0xFF6B6B70),
    accent: const Color(0xFF0A84FF),
    success: const Color(0xFF32D74B),
    redirect: const Color(0xFF64A8FF),
    clientError: const Color(0xFFFFD60A),
    serverError: const Color(0xFFFF6B5E),
    pending: const Color(0xFF98989D),
    cancelled: const Color(0xFF98989D),
    failure: const Color(0xFFFF6B5E),
    highlight: const Color(0xFF5C4A14),
    methodColors: _methodColors(dark: true),
    largeTitle: _largeTitle.copyWith(color: const Color(0xFFFFFFFF)),
    headline: _headline.copyWith(color: const Color(0xFFFFFFFF)),
    body: _body.copyWith(color: const Color(0xFFFFFFFF)),
    footnote: _footnote.copyWith(color: const Color(0xFF98989D)),
    caption: _caption.copyWith(color: const Color(0xFF98989D)),
    mono: _mono.copyWith(color: const Color(0xFFFFFFFF)),
    gutter: 16,
    rowSpacing: 8,
    radius: 10,
    hairline: 0.5,
    minRowHeight: 44,
    minTapTarget: 48,
  );

  /// The theme registered on [context], or Peek's own at that brightness.
  ///
  /// This is the one place Peek looks at the app's theme, and it looks only
  /// for the brightness: none of the app's colours reach Peek's widgets.
  static PeekTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PeekTheme>() ?? fromBrightness(theme.brightness);
  }

  /// Peek's own theme at [brightness].
  static PeekTheme fromBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? PeekTheme.dark() : PeekTheme.light();

  /// Behind the screens themselves.
  final Color background;

  /// Behind grouped sections, so their cards stand off it.
  final Color groupedBackground;

  /// A grouped section's own surface.
  final Color card;

  /// Behind controls that sit on the background: fields, segments, chips.
  final Color fill;

  /// The hairline between rows.
  final Color separator;

  /// Primary text.
  final Color label;

  /// Text that supports the primary: hosts, values, counts.
  final Color secondaryLabel;

  /// Dimmer still, and only for marks: chevrons, dots, disabled glyphs.
  /// Text never uses it — a grey light enough to read as a third level
  /// cannot also clear the contrast a reader needs.
  final Color tertiaryLabel;

  /// What the eye is drawn to: the chosen segment, a link, an active icon.
  /// Apple's system blue, as Pulse wears it.
  ///
  /// White on it is 4.0:1 — under what WCAG asks of small text, and a
  /// deliberate exception the rest of the palette does not take. Badges,
  /// chosen pills and the arrivals button carry it knowingly; ordinary
  /// text never sits on the accent.
  final Color accent;

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

  /// A call the app cancelled on purpose.
  final Color cancelled;

  /// A call that failed before a status could arrive.
  final Color failure;

  /// The wash behind text a search matched.
  final Color highlight;

  /// Colour per HTTP method, keyed uppercase; unknown methods fall back to
  /// [pending].
  final Map<String, Color> methodColors;

  /// The screen's own name, at the top of it.
  final TextStyle largeTitle;

  /// The line that names a row.
  final TextStyle headline;

  /// Ordinary text.
  final TextStyle body;

  /// The line under a row's name.
  final TextStyle footnote;

  /// Timestamps, counts and section headings.
  final TextStyle caption;

  /// Payloads: bodies, headers, anything whose alignment carries meaning.
  final TextStyle mono;

  /// Horizontal padding of Peek's screens.
  final double gutter;

  /// Vertical space between rows of a list.
  final double rowSpacing;

  /// Corner radius of cards, fields and segments.
  final double radius;

  /// The thickness of a separator.
  final double hairline;

  /// The least a row may be tall.
  final double minRowHeight;

  /// The least a control that answers a tap may be, either way. Android's
  /// accessibility guideline asks for 48, and it wins over the 44 an iOS
  /// row would use.
  final double minTapTarget;

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
  /// replaced it. A cancellation is not an error, so it stays neutral.
  Color colorForEntry(PeekEntry entry) {
    final statusClass = entry.statusClass;
    if (statusClass != null) return colorForStatusClass(statusClass);
    final kind = entry.failure?.kind;
    if (kind == null) return pending;
    return kind == PeekFailureKind.cancelled ? cancelled : failure;
  }

  /// The colour standing for [method], case-insensitively.
  Color colorForMethod(String method) =>
      methodColors[method.toUpperCase()] ?? pending;

  @override
  PeekTheme copyWith({
    Color? background,
    Color? groupedBackground,
    Color? card,
    Color? fill,
    Color? separator,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? accent,
    Color? success,
    Color? redirect,
    Color? clientError,
    Color? serverError,
    Color? pending,
    Color? cancelled,
    Color? failure,
    Color? highlight,
    Map<String, Color>? methodColors,
    TextStyle? largeTitle,
    TextStyle? headline,
    TextStyle? body,
    TextStyle? footnote,
    TextStyle? caption,
    TextStyle? mono,
    double? gutter,
    double? rowSpacing,
    double? radius,
    double? hairline,
    double? minRowHeight,
    double? minTapTarget,
  }) => PeekTheme(
    background: background ?? this.background,
    groupedBackground: groupedBackground ?? this.groupedBackground,
    card: card ?? this.card,
    fill: fill ?? this.fill,
    separator: separator ?? this.separator,
    label: label ?? this.label,
    secondaryLabel: secondaryLabel ?? this.secondaryLabel,
    tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
    accent: accent ?? this.accent,
    success: success ?? this.success,
    redirect: redirect ?? this.redirect,
    clientError: clientError ?? this.clientError,
    serverError: serverError ?? this.serverError,
    pending: pending ?? this.pending,
    cancelled: cancelled ?? this.cancelled,
    failure: failure ?? this.failure,
    highlight: highlight ?? this.highlight,
    methodColors: methodColors ?? this.methodColors,
    largeTitle: largeTitle ?? this.largeTitle,
    headline: headline ?? this.headline,
    body: body ?? this.body,
    footnote: footnote ?? this.footnote,
    caption: caption ?? this.caption,
    mono: mono ?? this.mono,
    gutter: gutter ?? this.gutter,
    rowSpacing: rowSpacing ?? this.rowSpacing,
    radius: radius ?? this.radius,
    hairline: hairline ?? this.hairline,
    minRowHeight: minRowHeight ?? this.minRowHeight,
    minTapTarget: minTapTarget ?? this.minTapTarget,
  );

  @override
  PeekTheme lerp(covariant PeekTheme? other, double t) {
    if (other == null) return this;
    Color color(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle type(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    double size(double a, double b) => a + (b - a) * t;

    return PeekTheme(
      background: color(background, other.background),
      groupedBackground: color(groupedBackground, other.groupedBackground),
      card: color(card, other.card),
      fill: color(fill, other.fill),
      separator: color(separator, other.separator),
      label: color(label, other.label),
      secondaryLabel: color(secondaryLabel, other.secondaryLabel),
      tertiaryLabel: color(tertiaryLabel, other.tertiaryLabel),
      accent: color(accent, other.accent),
      success: color(success, other.success),
      redirect: color(redirect, other.redirect),
      clientError: color(clientError, other.clientError),
      serverError: color(serverError, other.serverError),
      pending: color(pending, other.pending),
      cancelled: color(cancelled, other.cancelled),
      failure: color(failure, other.failure),
      highlight: color(highlight, other.highlight),
      methodColors: {
        for (final name in {...methodColors.keys, ...other.methodColors.keys})
          name: color(
            methodColors[name] ?? pending,
            other.methodColors[name] ?? other.pending,
          ),
      },
      largeTitle: type(largeTitle, other.largeTitle),
      headline: type(headline, other.headline),
      body: type(body, other.body),
      footnote: type(footnote, other.footnote),
      caption: type(caption, other.caption),
      mono: type(mono, other.mono),
      gutter: size(gutter, other.gutter),
      rowSpacing: size(rowSpacing, other.rowSpacing),
      radius: size(radius, other.radius),
      hairline: size(hairline, other.hairline),
      minRowHeight: size(minRowHeight, other.minRowHeight),
      minTapTarget: size(minTapTarget, other.minTapTarget),
    );
  }

  static const TextStyle _largeTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static const TextStyle _headline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle _body = TextStyle(fontSize: 14, height: 1.3);

  static const TextStyle _footnote = TextStyle(fontSize: 13, height: 1.3);

  static const TextStyle _caption = TextStyle(fontSize: 11, height: 1.2);

  static const TextStyle _mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'monospace'],
    fontSize: 12,
    height: 1.4,
  );

  static Map<String, Color> _methodColors({required bool dark}) => {
    'GET': dark ? const Color(0xFF64A8FF) : const Color(0xFF0A6FD8),
    'POST': dark ? const Color(0xFF32D74B) : const Color(0xFF0F9D58),
    'PUT': dark ? const Color(0xFFFFD60A) : const Color(0xFFB26A00),
    'PATCH': dark ? const Color(0xFFFFD60A) : const Color(0xFFB26A00),
    'DELETE': dark ? const Color(0xFFFF6B5E) : const Color(0xFFD70015),
    'HEAD': dark ? const Color(0xFF98989D) : const Color(0xFF6A6A6F),
    'OPTIONS': dark ? const Color(0xFF98989D) : const Color(0xFF6A6A6F),
  };
}
