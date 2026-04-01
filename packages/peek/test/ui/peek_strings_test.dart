import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/entries.dart';
import '../support/fake_store.dart';
import '../support/pump.dart';

/// Widget code must read its words from [PeekStrings], so a literal handed
/// to a widget that renders or announces text can never be translated.
///
/// Font names, map keys and assert messages are not user-facing, so the
/// scan looks only where text reaches the screen: `Text(...)` and the named
/// arguments that carry a label.
final List<RegExp> _renderedText = [
  RegExp(r'''\b(?:Text|SelectableText)\(\s*(?:const\s+)?['"]'''),
  RegExp(
    r'''\b(?:message|semanticsLabel|hintText|labelText|helperText'''
    r'''|errorText|tooltip):\s*(?:const\s+)?['"]''',
  ),
];

const Set<String> _exempt = {'peek_strings.dart'};

List<String> literalsIn(File file) {
  final offenders = <String>[];
  var lineNumber = 0;
  for (final line in file.readAsLinesSync()) {
    lineNumber++;
    final trimmed = line.trim();
    if (trimmed.startsWith('///') ||
        trimmed.startsWith('//') ||
        trimmed.contains('ignore: peek-literal')) {
      continue;
    }
    if (_renderedText.any((pattern) => pattern.hasMatch(line))) {
      offenders.add('${file.path}:$lineNumber: $trimmed');
    }
  }
  return offenders;
}

void main() {
  group('PeekStrings', () {
    test('names every enum value it has to name', () {
      const strings = PeekStrings();
      for (final kind in PeekFailureKind.values) {
        expect(strings.failureKind(kind), isNotEmpty, reason: kind.name);
      }
      for (final state in PeekEntryState.values) {
        expect(strings.entryState(state), isNotEmpty, reason: state.name);
      }
      for (final scope in PeekSearchScope.values) {
        expect(strings.searchScope(scope), isNotEmpty, reason: scope.name);
      }
      for (final reason in PeekBodyUnavailableReason.values) {
        expect(strings.unavailableBody(reason), isNotEmpty);
      }
      for (final field in PeekSortField.values) {
        for (final descending in [true, false]) {
          expect(
            strings.sortOption(field, descending: descending),
            isNotEmpty,
            reason: '${field.name} $descending',
          );
        }
      }
    });

    test('counts and sizes read naturally', () {
      const strings = PeekStrings();
      expect(strings.requestCount(6, 6), '6');
      expect(strings.requestCount(2, 6), '2 of 6');
      expect(strings.activeFilters(3), '3 active');
      expect(strings.newRequests(1), '1 new request');
      expect(strings.newRequests(4), '4 new requests');
      expect(strings.bytes(2048), '2 KB');
      expect(strings.elapsed(const Duration(milliseconds: 250)), '250 ms');
      expect(strings.truncatedBody(512, 5120), 'Showing 512 B of 5 KB');
      expect(strings.moreCharacters(12), '12 more characters');
      expect(
        strings.metrics(const Duration(milliseconds: 120), 179),
        '120 ms · 179 B',
      );
      expect(strings.metrics(const Duration(seconds: 30), null), '30 s');
      expect(strings.metrics(null, 0), isEmpty);
      expect(strings.metrics(null, null), isEmpty);
    });

    test('describes an entry for a screen reader', () {
      const strings = PeekStrings();
      expect(
        strings.entrySemantics(e1),
        'GET, api.example.com, /users, Status 200, 120 ms',
      );
      expect(strings.entrySemantics(e4), endsWith('Pending'));
      expect(strings.entrySemantics(e5), contains('Timed out'));
      expect(strings.entrySemantics(e5), endsWith('Pinned'));
    });

    test('can be translated by subclassing', () {
      const translated = _Translated();
      expect(translated.requests, 'Requêtes');
      expect(translated.search, const PeekStrings().search);
      expect(translated.entrySemantics(e1), startsWith('GET'));
    });

    testWidgets('reaches widgets through the scope', (tester) async {
      final (:peek, :store, :clock) = fakePeek(entries: fixtures);
      final controller = PeekController(peek);
      addTearDown(controller.dispose);
      addTearDown(peek.dispose);

      await pumpPeek(
        tester,
        PeekScope(
          controller: controller,
          strings: const _Translated(),
          child: Builder(
            builder: (context) => Text(PeekScope.stringsOf(context).requests),
          ),
        ),
      );
      expect(find.text('Requêtes'), findsOneWidget);
    });

    testWidgets('defaults to English when none is given', (tester) async {
      final (:peek, :store, :clock) = fakePeek();
      final controller = PeekController(peek);
      addTearDown(controller.dispose);
      addTearDown(peek.dispose);

      await pumpPeek(
        tester,
        PeekScope(
          controller: controller,
          child: Builder(
            builder: (context) => Text(PeekScope.stringsOf(context).requests),
          ),
        ),
      );
      expect(find.text('Requests'), findsOneWidget);
    });
  });

  group('widget code', () {
    test('holds no user-facing string literals', () {
      final directory = Directory('lib/src/ui');
      expect(directory.existsSync(), isTrue);

      final offenders = [
        for (final entity in directory.listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              !_exempt.any(entity.path.endsWith))
            ...literalsIn(entity),
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'Move these into PeekStrings:\n${offenders.join('\n')}',
      );
    });

    test('the scan finds a planted literal', () {
      final directory = Directory.systemTemp.createTempSync('peek_strings');
      addTearDown(() => directory.deleteSync(recursive: true));
      final offender = File('${directory.path}/widget.dart')..writeAsStringSync(
        [
          '/// A doc comment with words.',
          "const fontFamily = 'monospace';",
          "const methods = {'GET': 1};",
          "assert(scope != null, 'developer facing message');",
          "const Text('Hello'),",
          "Tooltip(message: 'Pin this'),",
          "Semantics(semanticsLabel: 'Loading'),",
          'Text(strings.requests),',
        ].join('\n'),
      );
      final found = literalsIn(offender);
      expect(found, hasLength(3));
      expect(found[0], endsWith("const Text('Hello'),"));
      expect(found[1], endsWith("Tooltip(message: 'Pin this'),"));
      expect(found[2], endsWith("Semantics(semanticsLabel: 'Loading'),"));
      expect(found.join(), isNot(contains('strings.requests')));
      expect(found.join(), isNot(contains('monospace')));
    });
  });
}

final class _Translated extends PeekStrings {
  const _Translated();

  @override
  String get requests => 'Requêtes';
}
