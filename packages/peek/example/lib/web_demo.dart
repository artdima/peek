import 'dart:math' show pi;
import 'dart:ui' show FlutterView, PointerDeviceKind;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'web_demo_page.dart'
    if (dart.library.js_interop) 'web_demo_page_web.dart';

/// What a view of the web page shows: one of the two apps on the left
/// phone, or Peek on the right.
enum DemoPhone {
  /// A sneaker shop whose server is pretended inside the page; the left
  /// phone opens with it.
  shop,

  /// The example itself, scenarios that make real calls; the page calls it
  /// the playground.
  example,

  /// Peek, showing the calls as they are made.
  peek;

  /// What the page asked view [viewId] to show; [shop] when it named
  /// nothing.
  static DemoPhone of(int viewId) =>
      values.asNameMap()[pageRoleOf(viewId)] ?? shop;
}

/// The phones' theme, as the switch above them picks it.
abstract final class DemoTheme {
  /// The pick so far; the system's while there is none.
  static ThemeMode get current => _modeOf(pageTheme()) ?? ThemeMode.system;

  /// Calls [listener] with each new pick.
  static void listen(ValueChanged<ThemeMode> listener) => onPageTheme((theme) {
    if (_modeOf(theme) case final mode?) listener(mode);
  });

  static ThemeMode? _modeOf(String? theme) => switch (theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => null,
  };
}

/// One widget per view the page adds, so a single program draws on both
/// phones and shares everything it holds between them.
///
/// The page changes the app on a phone by replacing its view with one
/// that names another, so views come and go while the program runs.
class DemoViews extends StatefulWidget {
  /// Creates the views, each showing what [builder] gives for its phone.
  const DemoViews({required this.builder, super.key});

  /// What each phone shows, given which phone it is.
  final Widget Function(DemoPhone phone) builder;

  @override
  State<DemoViews> createState() => _DemoViewsState();
}

class _DemoViewsState extends State<DemoViews> with WidgetsBindingObserver {
  late List<FlutterView> _views = _current();

  List<FlutterView> _current() => [
    ...WidgetsBinding.instance.platformDispatcher.views,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Views come and go through the same notification as a resize.
    final views = _current();
    if (!listEquals(views, _views)) setState(() => _views = views);
  }

  @override
  Widget build(BuildContext context) => ViewCollection(
    views: [
      for (final view in _views)
        View(
          key: ValueKey(view.viewId),
          view: view,
          child: widget.builder(DemoPhone.of(view.viewId)),
        ),
    ],
  );
}

/// A phone's screen on the page: the app is laid out at [size] and scaled
/// to the room the page gave it, under a status bar and over a home
/// indicator, with the room those take handed to it as padding.
///
/// It behaves as an iPhone too, whatever the browser runs on: its page
/// transitions, no desktop scrollbars, and a mouse drags a list the way a
/// finger would.
///
/// Meant for `MaterialApp.builder`, so a route pushed later is on the
/// phone too.
class PhoneScreen extends StatelessWidget {
  /// Puts [child] on the screen.
  const PhoneScreen({required this.child, super.key});

  /// What the app is laid out at, in logical pixels: an iPhone 15's
  /// screen. The page keeps the same proportions, so nothing is stretched.
  static const Size size = Size(393, 852);

  /// What the status bar and the home indicator take from the app.
  static const EdgeInsets insets = EdgeInsets.only(top: 59, bottom: 34);

  /// The app.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink =
        theme.brightness == Brightness.dark
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF000000);
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: size, padding: insets, viewPadding: insets),
          child: Stack(
            children: [
              Positioned.fill(
                child: Theme(
                  data: theme.copyWith(platform: TargetPlatform.iOS),
                  child: ScrollConfiguration(
                    behavior: const _PhoneScrolling(),
                    child: child,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _StatusBar(ink: ink)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 134,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrolling as on an iPhone, with a mouse among the fingers.
class _PhoneScrolling extends MaterialScrollBehavior {
  const _PhoneScrolling();

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.iOS;

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// The time on the left of the island, signal, Wi-Fi and battery on its
/// right.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.ink});

  static const Size _island = Size(125, 37);
  static const double _islandTop = 11;

  final Color ink;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PhoneScreen.insets.top,
    child: Stack(
      children: [
        // Hardware, so black whatever the app draws.
        Positioned(
          top: _islandTop,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox.fromSize(
              size: _island,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(_island.height / 2),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: _islandTop,
          height: _island.height,
          left: 0,
          right: 0,
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    '9:41',
                    // A status bar keeps its size whatever the text size.
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      inherit: false,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1,
                      color: ink,
                    ),
                  ),
                ),
              ),
              SizedBox(width: _island.width),
              Expanded(
                child: Center(
                  child: CustomPaint(
                    size: const Size(68, 12),
                    painter: _Glyphs(ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Full signal, Wi-Fi and a charged battery, drawn rather than taken from
/// an icon font so they look the part.
class _Glyphs extends CustomPainter {
  const _Glyphs(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = ink;
    final bottom = size.height - 0.5;

    for (var i = 0; i < 4; i++) {
      final left = i * 4.6;
      final height = 4 + i * 2.4;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          bottom - height,
          left + 3,
          bottom,
          const Radius.circular(0.9),
        ),
        fill,
      );
    }

    // Wi-Fi: a wedge and two bands, all opening upwards from one point.
    final center = Offset(30.5, bottom);
    const start = -3 * pi / 4;
    const sweep = pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 3.6),
      start,
      sweep,
      true,
      fill,
    );
    final band =
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.1
          ..strokeCap = StrokeCap.round;
    for (final radius in const [7.2, 10.9]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        band,
      );
    }

    final body = RRect.fromLTRBR(
      42,
      bottom - 11.5,
      66,
      bottom,
      const Radius.circular(3.4),
    );
    canvas
      ..drawRRect(
        body,
        Paint()
          ..color = ink.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawRRect(body.deflate(2), fill)
      ..drawRRect(
        RRect.fromLTRBR(
          67,
          bottom - 7.6,
          68.4,
          bottom - 3.9,
          const Radius.circular(0.7),
        ),
        Paint()..color = ink.withValues(alpha: 0.4),
      );
  }

  @override
  bool shouldRepaint(_Glyphs oldDelegate) => oldDelegate.ink != ink;
}
