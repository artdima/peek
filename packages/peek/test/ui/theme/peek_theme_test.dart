import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/pump.dart';

/// Widgets must take their colours from [PeekTheme], not from the app's
/// Material theme: Peek looks the same wherever it is embedded.
List<String> materialThemeUses(File file) {
  final pattern = RegExp(r'(?<!Peek)Theme\.of\(');
  final offenders = <String>[];
  var lineNumber = 0;
  for (final line in file.readAsLinesSync()) {
    lineNumber++;
    if (pattern.hasMatch(line)) {
      offenders.add('${file.path}:$lineNumber: ${line.trim()}');
    }
  }
  return offenders;
}

void main() {
  group('PeekTheme', () {
    test('maps every status class to a colour', () {
      final theme = PeekTheme.light();
      expect(theme.colorForStatusClass(PeekStatusClass.success), theme.success);
      expect(
        theme.colorForStatusClass(PeekStatusClass.redirect),
        theme.redirect,
      );
      expect(
        theme.colorForStatusClass(PeekStatusClass.clientError),
        theme.clientError,
      );
      expect(
        theme.colorForStatusClass(PeekStatusClass.serverError),
        theme.serverError,
      );
      expect(
        theme.colorForStatusClass(PeekStatusClass.informational),
        theme.pending,
      );
      expect(theme.colorForStatusClass(PeekStatusClass.unknown), theme.pending);
    });

    test('colours an entry by its status, then by its outcome', () {
      final theme = PeekTheme.light();
      expect(theme.colorForEntry(e1), theme.success);
      expect(theme.colorForEntry(e2), theme.clientError);
      expect(theme.colorForEntry(e6), theme.serverError);
      expect(theme.colorForEntry(e4), theme.pending);
      expect(theme.colorForEntry(e5), theme.failure);
      expect(theme.colorForEntry(cancelled), theme.cancelled);
      expect(theme.failure, isNot(theme.cancelled));

      final failedWithStatus = e5.copyWith(
        response: PeekResponse(statusCode: 503),
      );
      expect(theme.colorForEntry(failedWithStatus), theme.serverError);
    });

    test('colours methods, ignoring case, and falls back for the rest', () {
      final theme = PeekTheme.light();
      expect(theme.colorForMethod('get'), theme.methodColors['GET']);
      expect(theme.colorForMethod('DELETE'), theme.methodColors['DELETE']);
      expect(theme.colorForMethod('PROPFIND'), theme.pending);
      expect(theme.methodColors.keys, containsAll(['GET', 'POST', 'DELETE']));
    });

    test('light and dark differ but keep the same shape', () {
      final light = PeekTheme.light();
      final dark = PeekTheme.dark();
      expect(light.success, isNot(dark.success));
      expect(light.background, isNot(dark.background));
      expect(light.card, isNot(dark.card));
      expect(light.label, isNot(dark.label));
      expect(light.highlight, isNot(dark.highlight));
      expect(dark.methodColors.keys, light.methodColors.keys);
      expect(dark.gutter, light.gutter);
      expect(light.mono.fontFamily, 'monospace');
      expect(light.body.fontFamily, isNull);
      expect(light.largeTitle.fontSize, greaterThan(light.body.fontSize!));
    });

    test('rises a level in the dark and stays put in the light', () {
      final light = PeekTheme.light();
      expect(light.elevated, same(light));

      final dark = PeekTheme.dark();
      final lifted = dark.elevated;
      // The sheet has colours of its own, a step up from the screen's.
      expect(lifted.groupedBackground, dark.sheet);
      expect(lifted.background, dark.sheet);
      expect(lifted.card, dark.sheetCard);
      expect(
        dark.sheet!.computeLuminance(),
        greaterThan(dark.background.computeLuminance()),
      );
      expect(
        dark.sheetCard!.computeLuminance(),
        greaterThan(dark.sheet!.computeLuminance()),
      );
      expect(
        lifted.fill.computeLuminance(),
        greaterThan(dark.fill.computeLuminance()),
      );
      // A translucent hairline lifts by covering more, not by lightening.
      expect(lifted.separator.a, greaterThan(dark.separator.a));
      // Only the surfaces move: ink and meaning stay where they were.
      expect(lifted.label, dark.label);
      expect(lifted.accent, dark.accent);
      expect(lifted.success, dark.success);
      expect(lifted.body, dark.body);
    });

    test('a dark theme without sheet colours lifts a card instead', () {
      final dark = PeekTheme.dark();
      final bare = PeekTheme(
        background: dark.background,
        groupedBackground: dark.groupedBackground,
        card: dark.card,
        fill: dark.fill,
        separator: dark.separator,
        label: dark.label,
        secondaryLabel: dark.secondaryLabel,
        tertiaryLabel: dark.tertiaryLabel,
        accent: dark.accent,
        success: dark.success,
        redirect: dark.redirect,
        clientError: dark.clientError,
        serverError: dark.serverError,
        pending: dark.pending,
        cancelled: dark.cancelled,
        failure: dark.failure,
        highlight: dark.highlight,
        methodColors: dark.methodColors,
        largeTitle: dark.largeTitle,
        headline: dark.headline,
        body: dark.body,
        footnote: dark.footnote,
        caption: dark.caption,
        mono: dark.mono,
        gutter: dark.gutter,
        rowSpacing: dark.rowSpacing,
        radius: dark.radius,
        hairline: dark.hairline,
        minRowHeight: dark.minRowHeight,
        minTapTarget: dark.minTapTarget,
      );
      expect(bare.sheet, isNull);
      expect(bare.elevated.groupedBackground, bare.card);
      expect(bare.elevated.card, bare.fill);
    });

    test('copies with replaced values', () {
      final theme = PeekTheme.light();
      final copy = theme.copyWith(pending: const Color(0xFF112233), gutter: 4);
      expect(copy.pending, const Color(0xFF112233));
      expect(copy.gutter, 4);
      expect(copy.success, theme.success);
      expect(copy.methodColors, theme.methodColors);
    });

    test('lerps colours, sizes and every method', () {
      final light = PeekTheme.light();
      final dark = PeekTheme.dark();
      expect(light.lerp(null, 0.5), same(light));
      expect(light.lerp(dark, 0), isA<PeekTheme>());

      final mid = light.lerp(dark, 0.5);
      expect(mid.success, Color.lerp(light.success, dark.success, 0.5));
      expect(mid.methodColors.keys, light.methodColors.keys);
      expect(
        mid.methodColors['GET'],
        Color.lerp(light.methodColors['GET'], dark.methodColors['GET'], 0.5),
      );

      final wider = light.copyWith(gutter: 20);
      expect(light.lerp(wider, 0.5).gutter, 18);
    });

    test('lerp covers a method the other side is missing', () {
      const purple = Color(0xFF9C27B0);
      final light = PeekTheme.light();
      final odd = light.copyWith(
        methodColors: {...light.methodColors, 'PROPFIND': purple},
      );
      expect(light.lerp(odd, 1).methodColors['PROPFIND'], purple);
      expect(odd.lerp(light, 1).methodColors['PROPFIND'], light.pending);
    });
  });

  group('PeekTheme.of', () {
    testWidgets('returns the registered extension untouched', (tester) async {
      final registered = PeekTheme.light().copyWith(
        pending: const Color(0xFF00FF00),
      );
      late PeekTheme found;
      await pumpPeek(
        tester,
        Builder(
          builder: (context) {
            found = PeekTheme.of(context);
            return const SizedBox();
          },
        ),
        theme: ThemeData(extensions: [registered]),
      );
      expect(found, same(registered));
      expect(found.pending, const Color(0xFF00FF00));
    });

    for (final brightness in Brightness.values) {
      testWidgets('takes only the brightness from the app in '
          '${brightness.name}', (tester) async {
        late PeekTheme derived;
        await pumpPeek(
          tester,
          Builder(
            builder: (context) {
              derived = PeekTheme.of(context);
              return const SizedBox();
            },
          ),
          brightness: brightness,
        );

        final expected = PeekTheme.fromBrightness(brightness);
        expect(derived.background, expected.background);
        expect(derived.accent, expected.accent);
        expect(derived.success, expected.success);
        expect(derived.label, expected.label);
      });
    }

    testWidgets('a scope comes before the registered extension', (
      tester,
    ) async {
      final registered = PeekTheme.light().copyWith(
        pending: const Color(0xFF00FF00),
      );
      final scoped = registered.copyWith(pending: const Color(0xFFFF0000));
      late PeekTheme outside;
      late PeekTheme inside;
      await pumpPeek(
        tester,
        Builder(
          builder: (context) {
            outside = PeekTheme.of(context);
            return PeekThemeScope(
              theme: scoped,
              child: Builder(
                builder: (context) {
                  inside = PeekTheme.of(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
        theme: ThemeData(extensions: [registered]),
      );
      expect(outside, same(registered));
      expect(inside, same(scoped));
    });

    testWidgets('none of the app colours reach it', (tester) async {
      late PeekTheme derived;
      await pumpPeek(
        tester,
        Builder(
          builder: (context) {
            derived = PeekTheme.of(context);
            return const SizedBox();
          },
        ),
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      );

      final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
      expect(derived.accent, isNot(scheme.primary));
      expect(derived.serverError, isNot(scheme.error));
      expect(derived.background, PeekTheme.light().background);
    });
  });

  group('widget code', () {
    test('reads its colours from PeekTheme alone', () {
      final directory = Directory('lib/src/ui');
      expect(directory.existsSync(), isTrue);

      final offenders = [
        for (final entity in directory.listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              !entity.path.endsWith('peek_theme.dart'))
            ...materialThemeUses(entity),
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'Read these from PeekTheme instead:\n${offenders.join('\n')}',
      );
    });

    test('the scan finds a planted read', () {
      final directory = Directory.systemTemp.createTempSync('peek_theme');
      addTearDown(() => directory.deleteSync(recursive: true));
      final offender = File('${directory.path}/widget.dart')..writeAsStringSync(
        [
          'final theme = PeekTheme.of(context);',
          'final scheme = Theme.of(context).colorScheme;',
          'style: Theme.of(context).textTheme.titleMedium,',
        ].join('\n'),
      );

      final found = materialThemeUses(offender);
      expect(found, hasLength(2));
      expect(found.join(), isNot(contains('PeekTheme.of')));
    });
  });

  group('status palette', () {
    for (final brightness in Brightness.values) {
      testWidgets('looks right in ${brightness.name}', (tester) async {
        await pumpPeek(
          tester,
          const _Palette(),
          brightness: brightness,
          size: const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(find.byType(_Palette), 'palette-${brightness.name}');
      });
    }
  });
}

class _Palette extends StatelessWidget {
  const _Palette();

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final swatches = <String, Color>{
      'success': theme.success,
      'redirect': theme.redirect,
      'clientError': theme.clientError,
      'serverError': theme.serverError,
      'pending': theme.pending,
      ...theme.methodColors,
    };
    return ColoredBox(
      color: theme.background,
      child: Padding(
        padding: EdgeInsets.all(theme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final MapEntry(:key, :value) in swatches.entries)
              Padding(
                padding: EdgeInsets.only(bottom: theme.rowSpacing),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: value,
                        borderRadius: BorderRadius.circular(theme.radius),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(key, style: theme.body),
                  ],
                ),
              ),
            for (final MapEntry(:key, :value)
                in <String, TextStyle>{
                  'largeTitle': theme.largeTitle,
                  'headline': theme.headline,
                  'body': theme.body,
                  'footnote': theme.footnote,
                  'caption': theme.caption,
                  'mono': theme.mono,
                }.entries)
              Text(key, style: value),
          ],
        ),
      ),
    );
  }
}
