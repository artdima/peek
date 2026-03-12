import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/pump.dart';

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
      expect(theme.colorForEntry(e5), theme.cancelled);
      expect(theme.colorForEntry(cancelled), theme.cancelled);

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
      expect(light.surface, isNot(dark.surface));
      expect(light.monoTextStyle.color, isNot(dark.monoTextStyle.color));
      expect(dark.methodColors.keys, light.methodColors.keys);
      expect(dark.gutter, light.gutter);
      expect(light.monoTextStyle.fontFamily, 'monospace');
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
      testWidgets('derives a ${brightness.name} theme from the app colours', (
        tester,
      ) async {
        late PeekTheme derived;
        late ColorScheme scheme;
        await pumpPeek(
          tester,
          Builder(
            builder: (context) {
              derived = PeekTheme.of(context);
              scheme = Theme.of(context).colorScheme;
              return const SizedBox();
            },
          ),
          brightness: brightness,
        );

        final expected =
            brightness == Brightness.dark
                ? PeekTheme.dark()
                : PeekTheme.light();
        expect(scheme.brightness, brightness);
        expect(derived.success, expected.success);
        expect(derived.clientError, expected.clientError);
        expect(derived.serverError, scheme.error);
        expect(derived.redirect, scheme.primary);
        expect(derived.surface, scheme.surfaceContainerLowest);
        expect(derived.monoTextStyle.color, scheme.onSurface);
      });
    }

    test('borrows error, primary and surface from a scheme', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
      final derived = PeekTheme.fromColorScheme(scheme);
      expect(derived.serverError, scheme.error);
      expect(derived.redirect, scheme.primary);
      expect(derived.surface, scheme.surfaceContainerLowest);
      expect(derived.monoTextStyle.color, scheme.onSurface);
      expect(derived.success, PeekTheme.light().success);
    });
  });

  group('status palette', () {
    for (final brightness in Brightness.values) {
      testWidgets('looks right in ${brightness.name}', (tester) async {
        await pumpPeek(
          tester,
          const _Palette(),
          brightness: brightness,
          size: const Size(320, 440),
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
      color: theme.surface,
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
                    Text(key, style: theme.monoTextStyle),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
