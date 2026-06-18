import 'package:flutter/material.dart';
import 'package:peek/peek.dart';

import 'demo_data.dart';

void main() => runApp(const PeekExampleApp());

/// Shows Peek's screens filled with demo data.
class PeekExampleApp extends StatefulWidget {
  /// Creates the example app.
  const PeekExampleApp({super.key});

  @override
  State<PeekExampleApp> createState() => _PeekExampleAppState();
}

class _PeekExampleAppState extends State<PeekExampleApp> {
  final Peek _peek = Peek();
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    fillWithDemoData(_peek);
  }

  @override
  void dispose() {
    _peek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Peek example',
    debugShowCheckedModeBanner: false,
    themeMode: _mode,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3DDC84)),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF3DDC84), brightness: Brightness.dark),
    builder: (context, child) => PeekOverlay(peek: _peek, child: child!),
    home: _Home(peek: _peek, mode: _mode, onModeChanged: (mode) => setState(() => _mode = mode)),
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.peek, required this.mode, required this.onModeChanged});

  final Peek peek;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Peek example'),
      actions: [
        IconButton(
          tooltip: 'Toggle theme',
          onPressed: () => onModeChanged(mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
          icon: Icon(mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
        ),
      ],
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A network logger already recorded these calls.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => peek.open(context),
            icon: const Icon(Icons.travel_explore),
            label: const Text('Open Peek'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => fillWithDemoData(peek), child: const Text('Add more demo data')),
        ],
      ),
    ),
  );
}
