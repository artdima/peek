import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:peek/peek.dart';

import 'clients.dart';
import 'demo_data.dart';
import 'scenarios.dart';
import 'share.dart';

void main() => runApp(const PeekExampleApp());

/// Makes real calls, two ways, so Peek has something real to show.
class PeekExampleApp extends StatefulWidget {
  /// Creates the example app.
  const PeekExampleApp({super.key});

  @override
  State<PeekExampleApp> createState() => _PeekExampleAppState();
}

class _PeekExampleAppState extends State<PeekExampleApp> {
  final Peek _peek = Peek();
  late final ExampleClients _clients = ExampleClients(_peek);
  late final PeekShareDelegate _share = buildShareDelegate();
  ThemeMode _mode = ThemeMode.system;

  @override
  void dispose() {
    _clients.dispose();
    _peek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Peek example',
    debugShowCheckedModeBanner: false,
    themeMode: _mode,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3DDC84)),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF3DDC84),
      brightness: Brightness.dark,
    ),
    builder:
        (context, child) =>
            PeekOverlay(peek: _peek, share: _share, child: child!),
    home: _Home(
      peek: _peek,
      clients: _clients,
      share: _share,
      mode: _mode,
      onModeChanged: (mode) => setState(() => _mode = mode),
    ),
  );
}

class _Home extends StatefulWidget {
  const _Home({
    required this.peek,
    required this.clients,
    required this.share,
    required this.mode,
    required this.onModeChanged,
  });

  final Peek peek;
  final ExampleClients clients;
  final PeekShareDelegate share;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  ExampleRoute _route = ExampleRoute.dio;
  final Set<String> _running = {};

  Future<void> _run(Scenario scenario) async {
    if (_running.contains(scenario.name)) return;
    setState(() => _running.add(scenario.name));
    try {
      await scenario.run(widget.clients.of(_route));
    } on DioException catch (_) {
      // Failing is what several of these are for; Peek already has it.
    } finally {
      if (mounted) setState(() => _running.remove(scenario.name));
    }
  }

  Future<void> _runAll() async {
    for (final scenario in scenarios) {
      await _run(scenario);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peek example'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed:
                () => widget.onModeChanged(
                  dark ? ThemeMode.light : ThemeMode.dark,
                ),
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<ExampleRoute>(
              segments: [
                for (final route in ExampleRoute.values)
                  ButtonSegment(value: route, label: Text(route.label)),
              ],
              selected: {_route},
              onSelectionChanged:
                  (selected) => setState(() => _route = selected.single),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Both routes report the same calls; only the way they reach '
              'Peek differs. Run a few, then open Peek.',
            ),
          ),
          for (final scenario in scenarios)
            ListTile(
              title: Text(scenario.name),
              subtitle: Text(scenario.detail),
              trailing:
                  _running.contains(scenario.name)
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.play_arrow),
              onTap: () => _run(scenario),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('Run them all'),
            onTap: _runAll,
          ),
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('Add calls without a network'),
            subtitle: const Text('The same screens, offline'),
            onTap: () => fillWithDemoData(widget.peek),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => showPeek(context, peek: widget.peek, share: widget.share),
        icon: const Icon(Icons.travel_explore),
        label: const Text('Open Peek'),
      ),
    );
  }
}
