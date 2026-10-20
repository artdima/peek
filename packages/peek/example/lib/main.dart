import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:peek/peek.dart';

import 'chopper_scenarios.dart';
import 'clients.dart';
import 'demo_data.dart';
import 'http_scenarios.dart';
import 'remote_setup.dart';
import 'scenarios.dart';
import 'share.dart';
import 'shop/shop_api.dart';
import 'shop/shop_app.dart';
import 'web_demo.dart';

void main() {
  // The web page embeds two views of one program, the app and Peek beside
  // it, so there is no implicit view to run in.
  if (PlatformDispatcher.instance.implicitView == null) {
    runWidget(const _WebDemo());
  } else {
    runApp(const PeekExampleApp());
  }
}

/// Makes real calls, four ways, so Peek has something real to show.
class PeekExampleApp extends StatefulWidget {
  /// Creates the example app.
  const PeekExampleApp({super.key});

  @override
  State<PeekExampleApp> createState() => _PeekExampleAppState();
}

class _PeekExampleAppState extends State<PeekExampleApp> {
  final Peek _peek = Peek();
  late final ExampleClients _clients = ExampleClients(_peek);
  late final PeekShareDelegate? _share = buildShareDelegate();
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    startRemote(_peek);
  }

  @override
  void dispose() {
    _clients.dispose();
    _peek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _app(
    title: 'Peek example',
    mode: _mode,
    home: _Home(
      peek: _peek,
      clients: _clients,
      share: _share,
      onModeChanged: (mode) => setState(() => _mode = mode),
    ),
  );
}

/// The example on its web page: an app on one phone and Peek on the
/// other, over one instance, so a call made on the left shows up on the
/// right. The left phone runs the example or the shop, as the page asks.
class _WebDemo extends StatefulWidget {
  const _WebDemo();

  @override
  State<_WebDemo> createState() => _WebDemoState();
}

class _WebDemoState extends State<_WebDemo> {
  // No remote: a browser tab cannot reach Peek Pro.
  final Peek _peek = Peek();
  late final ExampleClients _clients = ExampleClients(_peek);
  late final ShopApi _shop = ShopApi(buildShopClient(_peek));
  ThemeMode _mode = DemoTheme.current;

  @override
  void initState() {
    super.initState();
    DemoTheme.listen((mode) => setState(() => _mode = mode));
  }

  @override
  void dispose() {
    _clients.dispose();
    _shop.dio.close();
    _peek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DemoViews(
    builder:
        (phone) => _app(
          mode: _mode,
          builder: (context, child) => PhoneScreen(child: child!),
          theme: phone == DemoPhone.shop ? shopTheme(Brightness.light) : null,
          darkTheme:
              phone == DemoPhone.shop ? shopTheme(Brightness.dark) : null,
          home: switch (phone) {
            DemoPhone.example => _Home(
              peek: _peek,
              clients: _clients,
              share: null,
              onModeChanged: null,
            ),
            DemoPhone.shop => ShopHome(api: _shop),
            DemoPhone.peek => PeekScreen(peek: _peek),
          },
        ),
  );
}

/// An app around [home], in the example's colours unless given others.
///
/// Without a [title] the browser tab keeps the one its page gave it.
Widget _app({
  required ThemeMode mode,
  required Widget home,
  String? title,
  TransitionBuilder? builder,
  ThemeData? theme,
  ThemeData? darkTheme,
}) => MaterialApp(
  title: title,
  debugShowCheckedModeBanner: false,
  themeMode: mode,
  theme: theme ?? _Palette.light.themeData(Brightness.light),
  darkTheme: darkTheme ?? _Palette.dark.themeData(Brightness.dark),
  builder: builder,
  home: home,
);

/// The example's own colours: green ink on paper, or on near-black.
///
/// Peek takes only the brightness from here; everything the example draws
/// itself comes from this.
enum _Palette {
  light(
    background: Color(0xFFFFFFFF),
    ink: Color(0xFF141A16),
    secondary: Color(0xFF78827B),
    chipInk: Color(0xFF455048),
    fill: Color(0xFFF1F4F1),
    hairline: Color(0xFFECEFEC),
    border: Color(0xFFD4DCD6),
    accent: Color(0xFF1F7A3F),
    onAccent: Color(0xFFFFFFFF),
    badge: Color(0x3DFFFFFF),
    warning: Color(0xFF8A4B00),
    danger: Color(0xFFB3261E),
  ),
  dark(
    background: Color(0xFF0F1411),
    ink: Color(0xFFF2F5F2),
    secondary: Color(0xFF7F8A83),
    chipInk: Color(0xFFC1C8C3),
    fill: Color(0xFF232B26),
    hairline: Color(0xFF222624),
    border: Color(0xFF2E3832),
    accent: Color(0xFF5FCB84),
    onAccent: Color(0xFF0F1411),
    badge: Color(0xFF0F1411),
    warning: Color(0xFFFFB454),
    danger: Color(0xFFF2857C),
  );

  const _Palette({
    required this.background,
    required this.ink,
    required this.secondary,
    required this.chipInk,
    required this.fill,
    required this.hairline,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.badge,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color ink;
  final Color secondary;
  final Color chipInk;
  final Color fill;
  final Color hairline;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color badge;
  final Color warning;
  final Color danger;

  static const List<String> _monoFallback = [
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];

  TextStyle get title => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
    color: ink,
  );

  TextStyle get lead => TextStyle(fontSize: 15, height: 1.45, color: secondary);

  TextStyle get caption => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: secondary,
  );

  TextStyle get rowTitle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: ink,
  );

  TextStyle get rowDetail =>
      TextStyle(fontSize: 13, height: 1.35, color: secondary);

  TextStyle get button =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink);

  TextStyle mono(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: _monoFallback,
    fontSize: size,
    fontWeight: weight,
    height: 1.2,
    color: color ?? ink,
  );

  ThemeData themeData(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: background,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: background,
  );

  /// The colour a call's outcome reads in.
  Color outcome(PeekEntry entry) => switch (entry.statusClass) {
    PeekStatusClass.success ||
    PeekStatusClass.informational ||
    PeekStatusClass.redirect => accent,
    PeekStatusClass.clientError => warning,
    PeekStatusClass.serverError => danger,
    PeekStatusClass.unknown => secondary,
    null => switch (entry.failure?.kind) {
      null || PeekFailureKind.cancelled => secondary,
      _ => danger,
    },
  };
}

class _Home extends StatefulWidget {
  const _Home({
    required this.peek,
    required this.clients,
    required this.share,
    required this.onModeChanged,
  });

  final Peek peek;
  final ExampleClients clients;
  final PeekShareDelegate? share;

  /// Switches the theme; on the web page the switch is the page's, so
  /// there is none.
  final ValueChanged<ThemeMode>? onModeChanged;

  @override
  State<_Home> createState() => _HomeState();
}

/// What one row of the screen can do.
typedef _Scenario =
    ({
      String name,
      String detail,
      ScenarioGroup group,
      Future<void> Function() call,
    });

class _HomeState extends State<_Home> {
  static const PeekStrings _strings = PeekStrings();

  ExampleRoute _route = ExampleRoute.dio;
  final Set<String> _running = {};

  /// The call each scenario made last, by route and name, so its outcome
  /// can be read beside it.
  final Map<String, PeekId> _results = {};
  late final StreamSubscription<PeekStoreChange> _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.peek.store.changes.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    super.dispose();
  }

  /// What the current route can do, as a name and a call.
  List<_Scenario> get _scenarios => switch (_route) {
    ExampleRoute.chopper => [
      for (final scenario in chopperScenarios)
        (
          name: scenario.name,
          detail: scenario.detail,
          group: scenario.group,
          call: () => scenario.run(widget.clients.chopper),
        ),
    ],
    ExampleRoute.http => [
      for (final scenario in httpScenarios)
        (
          name: scenario.name,
          detail: scenario.detail,
          group: scenario.group,
          call: () => scenario.run(widget.clients.httpClient),
        ),
    ],
    _ => [
      for (final scenario in scenarios)
        (
          name: scenario.name,
          detail: scenario.detail,
          group: scenario.group,
          call: () => scenario.run(widget.clients.dioOf(_route)),
        ),
    ],
  };

  String _key(String name) => '${_route.name}/$name';

  Future<void> _run(String name, Future<void> Function() call) async {
    if (_running.contains(name)) return;
    final key = _key(name);
    final store = widget.peek.store;
    final before = {for (final entry in store.entries) entry.id};
    setState(() => _running.add(name));
    try {
      await call();
    } on Object catch (_) {
      // Failing is what several of these are for; Peek already has it.
    } finally {
      if (mounted) {
        // Whatever the call added, newest last: that is its outcome.
        final added = store.entries.where((e) => !before.contains(e.id));
        setState(() {
          _running.remove(name);
          if (added.isNotEmpty) _results[key] = added.last.id;
        });
      }
    }
  }

  Future<void> _runAll() async {
    for (final scenario in _scenarios) {
      await _run(scenario.name, scenario.call);
    }
  }

  PeekEntry? _resultOf(String name) {
    final id = _results[_key(name)];
    return id == null ? null : widget.peek.store.find(id);
  }

  /// The outcome in a few words: `200 · 515 ms`, `timed out · 1.0 s`,
  /// `200 · 1.1 s · 2 hops`.
  String _outcomeOf(PeekEntry entry) {
    final code = entry.statusCode;
    final failure = entry.failure;
    final hops = entry.response?.redirects.length ?? 0;
    return [
      if (code != null)
        '$code'
      else if (failure != null)
        _strings.failureKind(failure.kind).toLowerCase()
      else
        _strings.pending.toLowerCase(),
      if (entry.duration case final elapsed?) _strings.elapsed(elapsed),
      if (hops == 1) '1 hop' else if (hops > 1) '$hops hops',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark ? _Palette.dark : _Palette.light;
    final padding = MediaQuery.paddingOf(context);
    final rows = _scenarios;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              padding.top + 8,
              20,
              padding.bottom + 112,
            ),
            children: [
              if (widget.onModeChanged case final onModeChanged?)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Toggle theme',
                    color: palette.ink,
                    onPressed:
                        () => onModeChanged(
                          dark ? ThemeMode.light : ThemeMode.dark,
                        ),
                    icon: Icon(
                      dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
              Text('Peek example', style: palette.title),
              const SizedBox(height: 8),
              Text(
                'Every route reports the calls it makes; only the way they '
                'reach Peek differs. Run a few, then open Peek.',
                style: palette.lead,
              ),
              const SizedBox(height: 28),
              _Caption('Adapter', trailing: _route.package, palette: palette),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final route in ExampleRoute.values)
                    _Chip(
                      label: route.name,
                      selected: route == _route,
                      palette: palette,
                      onTap: () => setState(() => _route = route),
                    ),
                ],
              ),
              for (final group in ScenarioGroup.values)
                if (rows.any((row) => row.group == group)) ...[
                  const SizedBox(height: 28),
                  _Caption(group.label, palette: palette),
                  const SizedBox(height: 4),
                  _Rows(
                    palette: palette,
                    children: [
                      for (final row in rows)
                        if (row.group == group)
                          _ScenarioRow(
                            name: row.name,
                            detail: row.detail,
                            outcome: switch (_resultOf(row.name)) {
                              null => null,
                              final entry => (
                                label: _outcomeOf(entry),
                                color: palette.outcome(entry),
                              ),
                            },
                            running: _running.contains(row.name),
                            palette: palette,
                            onTap: () => _run(row.name, row.call),
                          ),
                    ],
                  ),
                ],
              const SizedBox(height: 28),
              _Caption('Offline', palette: palette),
              const SizedBox(height: 4),
              _Rows(
                palette: palette,
                children: [
                  _Row(
                    title: 'Add calls without a network',
                    detail: 'The same screens, offline',
                    palette: palette,
                    onTap: () => fillWithDemoData(widget.peek),
                    trailing: _PillButton(
                      icon: Icons.add,
                      label: 'Add',
                      palette: palette,
                      onTap: () => fillWithDemoData(widget.peek),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              count: widget.peek.store.length,
              palette: palette,
              onRunAll: _runAll,
              onOpen:
                  () =>
                      showPeek(context, peek: widget.peek, share: widget.share),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading in small capitals, with a note at the far end where there is
/// one.
class _Caption extends StatelessWidget {
  const _Caption(this.label, {required this.palette, this.trailing});

  final String label;
  final String? trailing;
  final _Palette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label.toUpperCase(), style: palette.caption)),
      if (trailing case final trailing?)
        Text(trailing, style: palette.mono(12, color: palette.secondary)),
    ],
  );
}

/// One of the routes, as a pill; the one in use reads in the accent.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? palette.accent : palette.fill,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Text(
          label,
          style: palette.mono(
            14,
            weight: FontWeight.w500,
            color: selected ? palette.onAccent : palette.chipInk,
          ),
        ),
      ),
    ),
  );
}

/// Rows with a hairline between each pair.
class _Rows extends StatelessWidget {
  const _Rows({required this.children, required this.palette});

  final List<Widget> children;
  final _Palette palette;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (index, child) in children.indexed) ...[
        if (index > 0) Container(height: 1, color: palette.hairline),
        child,
      ],
    ],
  );
}

/// A name, a line about it and something to press at the end.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.detail,
    required this.trailing,
    required this.palette,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String detail;
  final Widget? badge;
  final Widget trailing;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: palette.rowTitle),
                    if (badge case final badge?) badge,
                  ],
                ),
                const SizedBox(height: 2),
                Text(detail, style: palette.rowDetail),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    ),
  );
}

/// A scenario: run from the disc at its end, with how its last run went
/// beside its name.
class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.name,
    required this.detail,
    required this.outcome,
    required this.running,
    required this.palette,
    required this.onTap,
  });

  final String name;
  final String detail;
  final ({String label, Color color})? outcome;
  final bool running;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Row(
    title: name,
    detail: detail,
    palette: palette,
    onTap: onTap,
    badge: switch (outcome) {
      null => null,
      final outcome => _OutcomeChip(
        label: outcome.label,
        color: outcome.color,
        palette: palette,
      ),
    },
    trailing: _Disc(running: running, palette: palette, onTap: onTap),
  );
}

/// How a call went, in its colour: `404 · 690 ms`.
class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({
    required this.label,
    required this.color,
    required this.palette,
  });

  final String label;
  final Color color;
  final _Palette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: palette.mono(11, weight: FontWeight.w500, color: color),
    ),
  );
}

/// The play button: a disc that spins while the call is in flight.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.running,
    required this.palette,
    required this.onTap,
  });

  final bool running;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: palette.fill,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: running ? null : onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child:
              running
                  ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    ),
                  )
                  : Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: palette.accent,
                  ),
        ),
      ),
    ),
  );
}

/// A small outlined button with a glyph before its word.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: StadiumBorder(side: BorderSide(color: palette.border)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: palette.ink),
            const SizedBox(width: 6),
            Text(label, style: palette.button.copyWith(fontSize: 14)),
          ],
        ),
      ),
    ),
  );
}

/// Run everything, or go and look: the two things always within reach.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.palette,
    required this.onRunAll,
    required this.onOpen,
  });

  final int count;
  final _Palette palette;
  final VoidCallback onRunAll;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        boxShadow: [
          BoxShadow(
            color: palette.background,
            blurRadius: 16,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: _BarButton(
                onTap: onRunAll,
                color: Colors.transparent,
                side: BorderSide(color: palette.border),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_play, size: 20, color: palette.ink),
                    const SizedBox(width: 8),
                    Text('Run all', style: palette.button),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: _BarButton(
                onTap: onOpen,
                color: palette.accent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Open Peek',
                      style: palette.button.copyWith(color: palette.onAccent),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: palette.badge,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: palette
                            .mono(12, weight: FontWeight.w600)
                            .copyWith(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the bar's two buttons: full height, rounded, filled or outlined.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.onTap,
    required this.color,
    required this.child,
    this.side = BorderSide.none,
  });

  final VoidCallback onTap;
  final Color color;
  final BorderSide side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      side: side,
      borderRadius: BorderRadius.circular(14),
    );
    return Material(
      color: color,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(height: 50, child: child),
      ),
    );
  }
}
