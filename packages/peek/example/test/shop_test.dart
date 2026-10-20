import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';
import 'package:peek_example/shop/shop_api.dart';
import 'package:peek_example/shop/shop_app.dart';
import 'package:peek_example/shop/shop_server.dart';

void main() {
  late Peek peek;
  late ShopApi api;

  setUp(() {
    peek = Peek();
    api = ShopApi(buildShopClient(peek, server: PaceServer(latency: 0)));
  });

  tearDown(() {
    api.dio.close();
    peek.dispose();
  });

  group('PaceServer', () {
    test('lists the shoes, all or by category', () async {
      expect(await api.products(), hasLength(8));
      final running = await api.products(category: 'running');
      expect(running.map((product) => product.name), [
        'Drift 2',
        'Tempo X',
        'Summit Trail',
      ]);
    });

    test('gives a shoe in full, its last pair marked', () async {
      final product = await api.product('drift-2');
      expect(product.description, isNotEmpty);
      expect(product.sizes, hasLength(8));
      final last = product.sizes.singleWhere((size) => size.lastPair);
      expect(last.label, 'EU 44');
      expect(last.available, isTrue);
    });

    test('has sold the last pair by the time it is asked for', () async {
      final product = await api.product('drift-2');
      final last = product.sizes.singleWhere((size) => size.lastPair);

      await expectLater(
        api.add(product, product.colorways.first, last),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      final again = await api.product('drift-2');
      expect(
        again.sizes.singleWhere((size) => size.label == last.label).available,
        isFalse,
      );
      expect((await api.bag()).lines, isEmpty);
    });

    test('turns the first payment away, then takes the order', () async {
      final product = await api.product('meridian');
      final size = product.sizes.firstWhere(
        (size) => size.available && !size.lastPair,
      );
      final bag = await api.add(product, product.colorways.last, size);
      expect(bag.lines.single.colorway.name, 'White/Navy');
      expect(bag.total, 95);

      await expectLater(
        api.order(bag),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            503,
          ),
        ),
      );
      final order = await api.order(bag);
      expect(order.total, 95);
      expect((await api.bag()).lines, isEmpty);
    });

    test('keeps favourites until they are let go', () async {
      final product = await api.product('alto');
      await api.favourite(product, keep: true);
      expect((await api.favourites()).single.id, 'alto');
      await api.favourite(product, keep: false);
      expect(await api.favourites(), isEmpty);
    });

    test('answers reviews slowly, and for one shoe not at all', () async {
      expect((await api.reviews('drift-2')).count, 128);
      await expectLater(
        api.reviews('vector-mid'),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
    });

    test('reports every call to Peek', () async {
      await api.products();
      await api.bag();
      expect(peek.store.entries.map((entry) => entry.request.uri.path), [
        '/v1/products',
        '/v1/bag',
      ]);
    });
  });

  group('ShopHome', () {
    Future<void> pumpShop(WidgetTester tester, {double textScale = 1}) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: shopTheme(Brightness.light),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: ShopHome(api: api),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the shoes the server lists', (tester) async {
      await pumpShop(tester);

      expect(find.text('All Shoes (8)'), findsOneWidget);
      expect(find.text('Drift 2'), findsOneWidget);
    });

    testWidgets('puts a pair in the bag', (tester) async {
      await pumpShop(tester);

      await tester.tap(find.text('Drift 2'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('EU 42'));
      await tester.tap(find.text('EU 42'));
      await tester.tap(find.text('Add to Bag'));
      await tester.pumpAndSettle();

      expect(find.text('Added to Bag'), findsOneWidget);
      await tester.tap(find.text('View Bag'));
      await tester.pumpAndSettle();
      expect(find.text('Size EU 42'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
    });

    testWidgets('lays the catalogue out at twice the text size', (
      tester,
    ) async {
      await pumpShop(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Drift 2'), findsOneWidget);
    });
  });
}
