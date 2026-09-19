import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/entries.dart';
import '../support/fake_store.dart';
import '../support/pump.dart';

void main() {
  late Peek peek;
  late FakePeekStore store;
  late PeekController controller;
  late int notifications;

  void build({PeekQuery query = PeekQuery.none, List<PeekEntry>? entries}) {
    final wired = fakePeek(entries: entries ?? fixtures);
    peek = wired.peek;
    store = wired.store;
    controller = PeekController(peek, query: query);
    notifications = 0;
    controller.addListener(() => notifications++);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);
  }

  group('PeekController', () {
    test('starts with the store filtered and sorted', () {
      build();
      expect(idsOf(controller.entries), ['e6', 'e5', 'e4', 'e3', 'e2', 'e1']);
      expect(controller.totalCount, 6);
      expect(controller.facets.errors, 3);
      expect(controller.isFiltered, isFalse);
      expect(controller.searchText, isEmpty);
      expect(controller.selected, isNull);
    });

    test('honours a query it was given', () {
      build(
        query: const PeekQuery(
          filter: PeekFilter(onlyErrors: true),
          sort: PeekSort.oldestFirst,
        ),
      );
      expect(idsOf(controller.entries), ['e2', 'e5', 'e6']);
      expect(controller.isFiltered, isTrue);
      expect(controller.totalCount, 6);
    });

    test('follows the store', () async {
      build(entries: []);
      expect(controller.entries, isEmpty);

      store.upsert(e1);
      await pumpEventQueue();
      expect(idsOf(controller.entries), ['e1']);
      expect(controller.totalCount, 1);
      expect(notifications, 1);

      store.upsert(e1.copyWith(isPinned: true));
      await pumpEventQueue();
      expect(controller.entries.single.isPinned, isTrue);
      expect(notifications, 2);
    });

    test('replacing the query re-runs it at once', () {
      build();
      controller.filter = const PeekFilter(methods: {'GET'});
      expect(idsOf(controller.entries), ['e6', 'e4', 'e3', 'e1']);
      expect(notifications, 1);

      controller.sort = PeekSort.oldestFirst;
      expect(idsOf(controller.entries), ['e1', 'e3', 'e4', 'e6']);
      expect(notifications, 2);

      controller.filter = const PeekFilter(methods: {'GET'});
      expect(notifications, 2);
    });

    test('sortBy flips a repeated field', () {
      build();
      controller.sortBy(PeekSortField.duration);
      expect(controller.sort, PeekSort.slowestFirst);
      controller.sortBy(PeekSortField.duration);
      expect(controller.sort.descending, isFalse);
    });

    test('resetFilter clears the criteria but keeps the sort', () {
      build(
        query: const PeekQuery(
          filter: PeekFilter(onlyErrors: true),
          sort: PeekSort.slowestFirst,
        ),
      );
      controller.resetFilter();
      expect(controller.filter, PeekFilter.none);
      expect(controller.sort, PeekSort.slowestFirst);
      expect(controller.entries, hasLength(6));
    });

    test('waits for typing to pause before filtering', () {
      fakeAsync((async) {
        build();
        controller.searchFor('users');
        expect(controller.searchText, 'users');
        expect(controller.isSearchPending, isTrue);
        expect(controller.entries, hasLength(6));
        expect(notifications, 1);

        async.elapse(const Duration(milliseconds: 100));
        controller.searchFor('users/1');
        async.elapse(const Duration(milliseconds: 100));
        expect(controller.entries, hasLength(6));

        async.elapse(PeekController.searchDebounce);
        expect(controller.isSearchPending, isFalse);
        expect(idsOf(controller.entries), ['e5']);
        expect(controller.filter.query.text, 'users/1');
      });
    });

    test('ignores a repeated search and cancels the timer on dispose', () {
      fakeAsync((async) {
        build();
        controller.searchFor('x');
        expect(notifications, 1);
        controller.searchFor('x');
        expect(notifications, 1);

        controller.dispose();
        async.elapse(const Duration(seconds: 1));
      });
    });

    test('setting the query outright cancels pending typing', () {
      fakeAsync((async) {
        build();
        controller.searchFor('users');
        controller.filter = const PeekFilter(methods: {'POST'});
        async.elapse(const Duration(seconds: 1));
        expect(controller.filter.query.isEmpty, isTrue);
        expect(controller.searchText, isEmpty);
        expect(idsOf(controller.entries), ['e2']);
      });
    });

    test('narrows the search scopes at once', () {
      build();
      controller.searchIn({PeekSearchScope.url});
      expect(controller.filter.query.scopes, {PeekSearchScope.url});
      expect(controller.isSearchPending, isFalse);
    });

    test('keeps a selection and drops it when the entry goes', () async {
      build();
      controller.select(e1.id);
      expect(controller.selected, e1);
      expect(notifications, 1);
      controller.select(e1.id);
      expect(notifications, 1);

      store.remove(e1.id);
      await pumpEventQueue();
      expect(controller.selectedId, isNull);
      expect(controller.selected, isNull);

      controller.select(e2.id);
      store.clear();
      await pumpEventQueue();
      expect(controller.selectedId, isNull);
    });

    test('forgets a selection the store never had', () {
      build();
      controller.select(const PeekId('ghost'));
      expect(controller.selectedId, const PeekId('ghost'));
      expect(controller.selected, isNull);
      controller.select(null);
      expect(controller.selectedId, isNull);
    });

    test('hears a pause the app asked for, once', () async {
      build();
      peek.pause();
      await pumpEventQueue();
      expect(controller.isPaused, isTrue);
      expect(notifications, 1);

      controller.pause();
      await pumpEventQueue();
      expect(notifications, 1);

      controller.resume();
      expect(controller.isPaused, isFalse);
      expect(notifications, 2);
      await pumpEventQueue();
      expect(notifications, 2);
    });

    test('pins, pauses and clears through Peek', () async {
      build();
      expect(controller.togglePin(e1.id), isTrue);
      await pumpEventQueue();
      expect(peek.store.find(e1.id)?.isPinned, isTrue);
      expect(controller.togglePin(e1.id), isFalse);

      expect(controller.isPaused, isFalse);
      controller.togglePause();
      expect(controller.isPaused, isTrue);
      expect(peek.isPaused, isTrue);
      controller.togglePause();
      expect(peek.isPaused, isFalse);
      controller.pause();
      controller.pause();
      expect(peek.isPaused, isTrue);
      controller.resume();
      expect(peek.isPaused, isFalse);

      controller.select(e2.id);
      controller.clear();
      await pumpEventQueue();
      expect(controller.entries, isEmpty);
      expect(controller.selectedId, isNull);
    });

    test('stops listening to the store once disposed', () async {
      build();
      final before = notifications;
      controller.dispose();
      controller.dispose();
      store.upsert(e1.copyWith(isPinned: true));
      await pumpEventQueue();
      expect(notifications, before);
    });
  });

  group('PeekScope', () {
    testWidgets('hands the controller down and rebuilds on change', (
      tester,
    ) async {
      build();
      var builds = 0;
      await pumpPeek(
        tester,
        PeekScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              builds++;
              return Text('${PeekScope.of(context).entries.length}');
            },
          ),
        ),
      );
      expect(find.text('6'), findsOneWidget);
      expect(builds, 1);
      expect(PeekScope.peekOf(tester.element(find.text('6'))), same(peek));

      controller.filter = const PeekFilter(onlyErrors: true);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('read does not subscribe', (tester) async {
      build();
      var builds = 0;
      late BuildContext inner;
      await pumpPeek(
        tester,
        PeekScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              builds++;
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(PeekScope.read(inner), same(controller));
      expect(PeekScope.read(inner).peek, same(peek));

      controller.filter = const PeekFilter(onlyErrors: true);
      await tester.pump();
      expect(builds, 1);
    });
  });
}
