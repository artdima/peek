import 'package:dio/dio.dart';
import 'package:peek/peek.dart';
import 'package:peek_dio/peek_dio.dart';

import 'shop_server.dart';
import 'sneaker.dart';

/// The shop's client: Dio with Peek's interceptor, talking to [server], or
/// to a new [PaceServer].
Dio buildShopClient(Peek peek, {PaceServer? server}) =>
    Dio(
        BaseOptions(
          baseUrl: paceApi,
          headers: const {
            'Accept-Language': 'en-GB',
            'Authorization': 'Bearer pace_demo_8f2c41d07a',
            'X-App-Version': '4.2.0 (418)',
          },
        ),
      )
      ..httpClientAdapter = server ?? PaceServer()
      ..interceptors.add(PeekDioInterceptor(peek));

/// One of the colours a shoe comes in.
final class Colorway {
  /// Creates a colourway.
  const Colorway({required this.id, required this.name, required this.colors});

  /// Reads a colourway the server sent.
  factory Colorway.fromJson(Map<String, Object?> json) => Colorway(
    id: json['id']! as String,
    name: json['name']! as String,
    colors: SneakerColors.fromJson(_map(json['colors'])),
  );

  /// What the server knows it by.
  final String id;

  /// What a shopper reads: `Black/Ember`.
  final String name;

  /// What the drawing is painted in.
  final SneakerColors colors;
}

/// A size, and whether there is a pair of it.
final class ShoeSize {
  /// Creates a size.
  const ShoeSize({
    required this.label,
    required this.available,
    required this.lastPair,
  });

  /// Reads a size the server sent.
  factory ShoeSize.fromJson(Map<String, Object?> json) => ShoeSize(
    label: json['label']! as String,
    available: json['available']! as bool,
    lastPair: json['lastPair'] as bool? ?? false,
  );

  /// `EU 42`.
  final String label;

  /// Whether any are left.
  final bool available;

  /// Whether the server says only one pair is left.
  final bool lastPair;
}

/// A shoe in the shop.
final class Product {
  /// Creates a product.
  const Product({
    required this.id,
    required this.name,
    required this.label,
    required this.shape,
    required this.price,
    required this.colorways,
    this.badge,
    this.description,
    this.sizes = const [],
  });

  /// Reads a product the server sent, in summary or in full.
  factory Product.fromJson(Map<String, Object?> json) => Product(
    id: json['id']! as String,
    name: json['name']! as String,
    label: json['label']! as String,
    shape: SneakerShape.values.byName(json['shape']! as String),
    price: json['price']! as int,
    badge: json['badge'] as String?,
    description: json['description'] as String?,
    colorways: [
      for (final way in _list(json['colorways'])) Colorway.fromJson(_map(way)),
    ],
    sizes: [
      for (final size in _list(json['sizes'] ?? const <Object?>[]))
        ShoeSize.fromJson(_map(size)),
    ],
  );

  /// What the server knows it by.
  final String id;

  /// `Drift 2`.
  final String name;

  /// `Road Running Shoes`.
  final String label;

  /// Its outline.
  final SneakerShape shape;

  /// In whole dollars.
  final int price;

  /// `Just In`, `Bestseller`, or nothing.
  final String? badge;

  /// The colours it comes in, the one shown first first.
  final List<Colorway> colorways;

  /// A line about it; only a product read in full has one.
  final String? description;

  /// Its sizes; only a product read in full has them.
  final List<ShoeSize> sizes;
}

/// One pair in the bag.
final class BagLine {
  /// Creates a line.
  const BagLine({
    required this.id,
    required this.name,
    required this.label,
    required this.shape,
    required this.colorway,
    required this.size,
    required this.price,
  });

  /// Reads a line the server sent.
  factory BagLine.fromJson(Map<String, Object?> json) => BagLine(
    id: json['id']! as String,
    name: json['name']! as String,
    label: json['category']! as String,
    shape: SneakerShape.values.byName(json['shape']! as String),
    colorway: Colorway.fromJson(_map(json['colorway'])),
    size: json['size']! as String,
    price: json['price']! as int,
  );

  /// What the server knows the line by.
  final String id;

  /// The product's name.
  final String name;

  /// The product's kind: `Road Running Shoes`.
  final String label;

  /// The product's outline.
  final SneakerShape shape;

  /// Which colours.
  final Colorway colorway;

  /// Which size.
  final String size;

  /// In whole dollars.
  final int price;
}

/// What is in the bag, and what it comes to.
final class Bag {
  /// Creates a bag.
  const Bag({required this.lines, required this.total});

  /// Reads a bag the server sent.
  factory Bag.fromJson(Map<String, Object?> json) => Bag(
    lines: [
      for (final line in _list(json['items'])) BagLine.fromJson(_map(line)),
    ],
    total: json['total']! as int,
  );

  /// A bag with nothing in it.
  static const Bag empty = Bag(lines: [], total: 0);

  /// The pairs, in the order they were added.
  final List<BagLine> lines;

  /// In whole dollars, delivery included; delivery is free.
  final int total;
}

/// One reviewer's word.
final class Review {
  /// Creates a review.
  const Review({
    required this.author,
    required this.rating,
    required this.title,
    required this.body,
  });

  /// Reads a review the server sent.
  factory Review.fromJson(Map<String, Object?> json) => Review(
    author: json['author']! as String,
    rating: json['rating']! as int,
    title: json['title']! as String,
    body: json['body']! as String,
  );

  /// Who wrote it.
  final String author;

  /// Out of five.
  final int rating;

  /// Its headline.
  final String title;

  /// What it says.
  final String body;
}

/// What the reviewers of a shoe think, on average and in their words.
final class Reviews {
  /// Creates the reviews.
  const Reviews({
    required this.average,
    required this.count,
    required this.items,
  });

  /// Reads the reviews the server sent.
  factory Reviews.fromJson(Map<String, Object?> json) => Reviews(
    average: (json['average']! as num).toDouble(),
    count: json['count']! as int,
    items: [
      for (final item in _list(json['items'])) Review.fromJson(_map(item)),
    ],
  );

  /// Out of five.
  final double average;

  /// How many there are in all.
  final int count;

  /// The few the server sent.
  final List<Review> items;
}

/// An order the server has taken.
final class Order {
  /// Creates an order.
  const Order({required this.id, required this.total, required this.arrives});

  /// Reads an order the server sent.
  factory Order.fromJson(Map<String, Object?> json) => Order(
    id: json['id']! as String,
    total: json['total']! as int,
    arrives: DateTime.parse(json['estimatedDelivery']! as String),
  );

  /// `PC-48213`.
  final String id;

  /// In whole dollars.
  final int total;

  /// When it should arrive.
  final DateTime arrives;
}

/// What the shop asks of its server. Each method is one call, so each
/// shows up in Peek as one.
final class ShopApi {
  /// Creates the API over [dio].
  const ShopApi(this.dio);

  /// The client the calls go through.
  final Dio dio;

  /// The shoes in [category], or all of them.
  Future<List<Product>> products({String? category}) async {
    final response = await dio.get<Object?>(
      'products',
      queryParameters: {if (category != null) 'category': category},
    );
    return [
      for (final item in _list(_map(response.data)['items']))
        Product.fromJson(_map(item)),
    ];
  }

  /// [id] in full: its sizes and what it is.
  Future<Product> product(String id) async {
    final response = await dio.get<Object?>('products/$id');
    return Product.fromJson(_map(response.data));
  }

  /// What reviewers think of [id].
  Future<Reviews> reviews(String id) async {
    final response = await dio.get<Object?>('products/$id/reviews');
    return Reviews.fromJson(_map(response.data));
  }

  /// What is in the bag.
  Future<Bag> bag() async {
    final response = await dio.get<Object?>('bag');
    return Bag.fromJson(_map(response.data));
  }

  /// Puts a pair of [product] in [colorway] and [size] in the bag.
  Future<Bag> add(Product product, Colorway colorway, ShoeSize size) async {
    final response = await dio.post<Object?>(
      'bag/items',
      data: {
        'productId': product.id,
        'colorway': colorway.id,
        'size': size.label,
        'quantity': 1,
      },
    );
    return Bag.fromJson(_map(response.data));
  }

  /// Takes [line] out of the bag.
  Future<Bag> remove(BagLine line) async {
    final response = await dio.delete<Object?>('bag/items/${line.id}');
    return Bag.fromJson(_map(response.data));
  }

  /// The shoes kept for later.
  Future<List<Product>> favourites() async {
    final response = await dio.get<Object?>('favourites');
    return [
      for (final item in _list(_map(response.data)['items']))
        Product.fromJson(_map(item)),
    ];
  }

  /// Keeps [product] for later, or stops keeping it.
  Future<void> favourite(Product product, {required bool keep}) async {
    final path = 'favourites/${product.id}';
    await (keep ? dio.put<void>(path) : dio.delete<void>(path));
  }

  /// Orders what is in [bag].
  Future<Order> order(Bag bag) async {
    final response = await dio.post<Object?>(
      'orders',
      data: {
        'items': [for (final line in bag.lines) line.id],
        'total': bag.total,
        'currency': 'USD',
        'payment': 'wallet',
      },
    );
    return Order.fromJson(_map(response.data));
  }
}

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

List<Object?> _list(Object? value) => value! as List<Object?>;
