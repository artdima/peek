import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

void main() {
  group('PeekFacets', () {
    test('counts totals, errors and pins', () {
      final facets = PeekFacets.of(fixtures);
      expect(facets.total, 6);
      expect(facets.errors, 3);
      expect(facets.pinned, 1);
    });

    test('ranks values by count, then by key', () {
      final facets = PeekFacets.of(fixtures);
      expect(facets.methods, {'GET': 4, 'DELETE': 1, 'POST': 1});
      expect(facets.methods.keys, ['GET', 'DELETE', 'POST']);
      expect(facets.hosts, {
        'api.example.com': 4,
        'cdn.example.com': 1,
        'other.example.com': 1,
      });
      expect(facets.hosts.keys, [
        'api.example.com',
        'cdn.example.com',
        'other.example.com',
      ]);
      expect(facets.sources, {'dio': 4, 'talker': 2});
      expect(facets.contentTypes, {
        'application/json': 2,
        'image/png': 1,
        'text/plain': 1,
      });
      expect(facets.statusCodes, {200: 2, 401: 1, 503: 1});
      expect(facets.statusCodes.keys, [200, 401, 503]);
      expect(facets.statusClasses, {
        PeekStatusClass.success: 2,
        PeekStatusClass.clientError: 1,
        PeekStatusClass.serverError: 1,
      });
      expect(facets.states, {
        PeekEntryState.completed: 4,
        PeekEntryState.pending: 1,
        PeekEntryState.failed: 1,
      });
    });

    test('hands out unmodifiable maps', () {
      final facets = PeekFacets.of(fixtures);
      expect(() => facets.methods['X'] = 1, throwsUnsupportedError);
    });

    test('is empty for no entries', () {
      final facets = PeekFacets.of(const []);
      expect(facets.total, 0);
      expect(facets.methods, isEmpty);
      expect(facets.statusClasses, isEmpty);
      expect(PeekFacets.empty.total, 0);
      expect(PeekFacets.empty.hosts, isEmpty);
    });

    test('prints a summary', () {
      expect(
        PeekFacets.of(fixtures).toString(),
        'PeekFacets(6 entries, 3 hosts, 3 methods)',
      );
    });
  });
}
