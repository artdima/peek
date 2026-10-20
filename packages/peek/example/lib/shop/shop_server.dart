import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Where the shop's server pretends to live; `.example` names never
/// resolve, so a copied cURL command reaches nobody.
const String paceApi = 'https://api.pace.example/v1/';

/// Pace's back end, pretended inside the app: a Dio adapter that answers
/// the shop's calls the way a server would, after a server's delay.
///
/// The calls still go through the client's interceptors, Peek's among
/// them, so they read in Peek like any other; only the network is left
/// out, which keeps the demo quick and the same for every visitor.
///
/// Two answers go wrong on purpose, the way they do in a real shop: the
/// size marked as the last pair has gone by the time it is added to the
/// bag (409), and the first payment finds the provider busy (503).
final class PaceServer implements HttpClientAdapter {
  /// Creates the server; [latency] scales how long it takes to answer, and
  /// 0 answers at once.
  PaceServer({this.latency = 1, Random? random})
    : _random = random ?? Random(7);

  /// How long answers take, as a share of a real server's time.
  final double latency;

  final Random _random;
  final List<Map<String, Object?>> _bag = [];
  final Set<String> _favourites = {};
  final Set<String> _soldOut = {};
  var _lines = 0;
  var _payments = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = _answer(options.method, options.uri, options.data);
    await Future<void>.delayed(reply.latency * latency);
    final body = reply.body;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      reply.status,
      statusMessage: _reasons[reply.status],
      headers: {
        if (body != null)
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        'cache-control': [reply.cache],
        'server': ['pace-api'],
        'x-request-id': [_requestId()],
        for (final MapEntry(:key, :value) in reply.headers.entries)
          key: [value],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  _Reply _answer(String method, Uri uri, Object? data) {
    final path = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty && segment != 'v1') segment,
    ];
    return switch ((method, path)) {
      ('GET', ['products']) => _products(uri.queryParameters['category']),
      ('GET', ['products', final id]) => _product(id),
      ('GET', ['products', final id, 'reviews']) => _reviews(id),
      ('GET', ['bag']) => _Reply(200, _bagJson(), _ms(180, 160)),
      ('POST', ['bag', 'items']) => _add(data),
      ('DELETE', ['bag', 'items', final line]) => _remove(line),
      ('GET', ['favourites']) => _favouritesReply(),
      ('PUT', ['favourites', final id]) => _favourite(id, keep: true),
      ('DELETE', ['favourites', final id]) => _favourite(id, keep: false),
      ('POST', ['orders']) => _order(),
      _ => _Reply(404, const {'error': 'not_found'}, _ms(90, 60)),
    };
  }

  _Reply _products(String? category) {
    final items = [
      for (final product in _catalog)
        if (category == null || product.category == category) product.summary(),
    ];
    return _Reply(
      200,
      {'items': items, 'count': items.length},
      _ms(260, 220),
      cache: 'public, max-age=300',
      headers: {'etag': 'W/"${_hex(8)}"'},
    );
  }

  _Reply _product(String id) {
    final product = _find(id);
    if (product == null) return _missing();
    return _Reply(
      200,
      product.detail(_soldOut),
      _ms(160, 140),
      cache: 'public, max-age=60',
    );
  }

  _Reply _reviews(String id) {
    final product = _find(id);
    if (product == null) return _missing();
    // The reviews service is the slow one, and for one shoe it is down.
    if (product.reviews.isEmpty) {
      return _Reply(500, const {
        'error': 'reviews_unavailable',
        'message': 'The reviews service did not answer.',
      }, _ms(900, 300));
    }
    final ratings = [for (final review in product.reviews) review.rating];
    final average = ratings.reduce((a, b) => a + b) / ratings.length;
    return _Reply(200, {
      'productId': id,
      'average': double.parse(average.toStringAsFixed(1)),
      'count': product.reviewCount,
      'items': [for (final review in product.reviews) review.json],
    }, _ms(1100, 400));
  }

  _Reply _add(Object? data) {
    final (productId, colorway, size) = switch (data) {
      {
        'productId': final String productId,
        'colorway': final String colorway,
        'size': final String size,
      } =>
        (productId, colorway, size),
      _ => (null, null, null),
    };
    final product = productId == null ? null : _find(productId);
    if (product == null || colorway == null || size == null) {
      return _Reply(422, const {
        'error': 'invalid_item',
        'message': 'An item needs a product, a colourway and a size.',
      }, _ms(120, 80));
    }
    final key = '$productId/$size';
    if (product.lastPair == size || _soldOut.contains(key)) {
      _soldOut.add(key);
      return _Reply(409, {
        'error': 'sold_out',
        'message': '$size has just sold out.',
        'productId': productId,
        'size': size,
      }, _ms(240, 160));
    }
    final way = product.colorways.firstWhere(
      (candidate) => candidate.id == colorway,
      orElse: () => product.colorways.first,
    );
    _bag.add({
      'id': 'line_${++_lines}',
      'productId': product.id,
      'name': product.name,
      'category': product.label,
      'shape': product.shape,
      'colorway': way.json,
      'size': size,
      'price': product.price,
    });
    return _Reply(201, _bagJson(), _ms(260, 180));
  }

  _Reply _remove(String line) {
    final before = _bag.length;
    _bag.removeWhere((item) => item['id'] == line);
    if (_bag.length == before) return _missing();
    return _Reply(200, _bagJson(), _ms(200, 120));
  }

  _Reply _favouritesReply() => _Reply(200, {
    'items': [
      for (final product in _catalog)
        if (_favourites.contains(product.id)) product.summary(),
    ],
  }, _ms(170, 140));

  _Reply _favourite(String id, {required bool keep}) {
    if (_find(id) == null) return _missing();
    if (keep) {
      _favourites.add(id);
    } else {
      _favourites.remove(id);
    }
    return _Reply(204, null, _ms(150, 120));
  }

  _Reply _order() {
    if (_bag.isEmpty) {
      return _Reply(422, const {
        'error': 'empty_bag',
        'message': 'There is nothing in the bag to order.',
      }, _ms(120, 80));
    }
    // The first payment of a visit finds the provider busy.
    if (_payments++ == 0) {
      return _Reply(
        503,
        const {
          'error': 'payment_unavailable',
          'message': 'The payment provider did not answer in time.',
        },
        _ms(1400, 300),
        headers: const {'retry-after': '2'},
      );
    }
    final total = _total();
    final id = 'PC-${10000 + _random.nextInt(89999)}';
    final arrives = DateTime.now().add(const Duration(days: 4));
    _bag.clear();
    return _Reply(
      201,
      {
        'id': id,
        'status': 'confirmed',
        'total': total,
        'currency': 'USD',
        'estimatedDelivery': arrives.toIso8601String().substring(0, 10),
      },
      _ms(800, 300),
      headers: {'location': '/v1/orders/$id'},
    );
  }

  Map<String, Object?> _bagJson() {
    final subtotal = _total();
    return {
      'items': List<Map<String, Object?>>.of(_bag),
      'subtotal': subtotal,
      'delivery': 0,
      'total': subtotal,
      'currency': 'USD',
    };
  }

  int _total() =>
      _bag.fold(0, (sum, item) => sum + ((item['price'] as int?) ?? 0));

  _Product? _find(String id) {
    for (final product in _catalog) {
      if (product.id == id) return product;
    }
    return null;
  }

  _Reply _missing() => _Reply(404, const {'error': 'not_found'}, _ms(90, 60));

  Duration _ms(int base, int spread) =>
      Duration(milliseconds: base + _random.nextInt(spread));

  String _requestId() => 'req_${_hex(12)}';

  String _hex(int length) =>
      [
        for (var i = 0; i < length; i++) _random.nextInt(16).toRadixString(16),
      ].join();

  static const Map<int, String> _reasons = {
    200: 'OK',
    201: 'Created',
    204: 'No Content',
    404: 'Not Found',
    409: 'Conflict',
    422: 'Unprocessable Entity',
    500: 'Internal Server Error',
    503: 'Service Unavailable',
  };
}

/// One answer: what it says, how long it took and how long to keep it.
final class _Reply {
  const _Reply(
    this.status,
    this.body,
    this.latency, {
    this.cache = 'no-store',
    this.headers = const {},
  });

  final int status;
  final Object? body;
  final Duration latency;
  final String cache;
  final Map<String, String> headers;
}

final class _Colorway {
  const _Colorway(this.id, this.name, this.colors);

  final String id;
  final String name;

  /// Upper, accent, sole, outsole, lace.
  final List<String> colors;

  Map<String, Object?> get json => {
    'id': id,
    'name': name,
    'colors': {
      'upper': colors[0],
      'accent': colors[1],
      'sole': colors[2],
      'outsole': colors[3],
      'lace': colors[4],
    },
  };
}

final class _Review {
  const _Review(this.author, this.rating, this.title, this.body);

  final String author;
  final int rating;
  final String title;
  final String body;

  Map<String, Object?> get json => {
    'author': author,
    'rating': rating,
    'title': title,
    'body': body,
  };
}

final class _Product {
  const _Product({
    required this.id,
    required this.name,
    required this.category,
    required this.label,
    required this.shape,
    required this.price,
    required this.colorways,
    required this.description,
    required this.lastPair,
    this.badge,
    this.gone = const [],
    this.reviews = const [],
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String category;
  final String label;
  final String shape;
  final int price;
  final String? badge;
  final List<_Colorway> colorways;
  final String description;

  /// The size shown as the last pair, which is gone when asked for.
  final String lastPair;

  /// The sizes there are none of.
  final List<String> gone;

  final List<_Review> reviews;
  final int reviewCount;

  static const List<String> sizes = [
    'EU 39',
    'EU 40',
    'EU 41',
    'EU 42',
    'EU 43',
    'EU 44',
    'EU 45',
    'EU 46',
  ];

  Map<String, Object?> summary() => {
    'id': id,
    'name': name,
    'category': category,
    'label': label,
    'shape': shape,
    'price': price,
    'currency': 'USD',
    'badge': badge,
    'colorways': [for (final way in colorways) way.json],
  };

  Map<String, Object?> detail(Set<String> soldOut) => {
    ...summary(),
    'description': description,
    'styleCode': '${id.toUpperCase()}-001',
    'sizes': [
      for (final size in sizes)
        {
          'label': size,
          'available': !gone.contains(size) && !soldOut.contains('$id/$size'),
          'lastPair': size == lastPair && !soldOut.contains('$id/$size'),
        },
    ],
  };
}

const List<_Product> _catalog = [
  _Product(
    id: 'drift-2',
    name: 'Drift 2',
    category: 'running',
    label: 'Road Running Shoes',
    shape: 'runner',
    price: 130,
    badge: 'Bestseller',
    lastPair: 'EU 44',
    gone: ['EU 39'],
    description:
        'A soft, rockered ride for the everyday miles, with a knit upper '
        'that breathes.',
    colorways: [
      _Colorway('black-ember', 'Black/Ember', [
        '#1C1C1E',
        '#FF5A36',
        '#F2F2F2',
        '#1C1C1E',
        '#FFFFFF',
      ]),
      _Colorway('white-ocean', 'White/Ocean', [
        '#F4F4F5',
        '#2563EB',
        '#FFFFFF',
        '#94A3B8',
        '#E5E7EB',
      ]),
      _Colorway('grey-lime', 'Grey/Lime', [
        '#9CA3AF',
        '#C6F432',
        '#F5F5F5',
        '#374151',
        '#FFFFFF',
      ]),
    ],
    reviewCount: 128,
    reviews: [
      _Review('Maya', 5, 'My daily trainer', 'Comfortable from the first run.'),
      _Review('Chris', 4, 'Runs a little small', 'Go half a size up.'),
    ],
  ),
  _Product(
    id: 'tempo-x',
    name: 'Tempo X',
    category: 'running',
    label: 'Road Racing Shoes',
    shape: 'runner',
    price: 180,
    badge: 'Just In',
    lastPair: 'EU 42',
    gone: ['EU 46'],
    description:
        'Light and springy for race day, with a stiff plate under the '
        'forefoot.',
    colorways: [
      _Colorway('electric', 'Electric/White', [
        '#2563EB',
        '#F8FAFC',
        '#FDE047',
        '#1E3A8A',
        '#FFFFFF',
      ]),
      _Colorway('coral', 'Coral/Black', [
        '#FB7185',
        '#111827',
        '#FFFFFF',
        '#111827',
        '#111827',
      ]),
    ],
    reviewCount: 41,
    reviews: [
      _Review('Lena', 5, 'Fast', 'Took a minute off my 10K.'),
      _Review('Tom', 4, 'Not for every day', 'Firm on long runs.'),
    ],
  ),
  _Product(
    id: 'summit-trail',
    name: 'Summit Trail',
    category: 'running',
    label: 'Trail Running Shoes',
    shape: 'runner',
    price: 145,
    lastPair: 'EU 43',
    description:
        'Grippy on wet rock and soft on the way down, with a toe bumper '
        'for the roots.',
    colorways: [
      _Colorway('olive', 'Olive/Amber', [
        '#4D5B3A',
        '#F59E0B',
        '#E7E5E4',
        '#292524',
        '#1C1917',
      ]),
      _Colorway('slate', 'Slate/Orange', [
        '#475569',
        '#F97316',
        '#E2E8F0',
        '#1E293B',
        '#F8FAFC',
      ]),
    ],
    reviewCount: 63,
    reviews: [
      _Review('Ana', 5, 'Sticks to anything', 'Muddy hills, no slips.'),
      _Review('Ben', 4, 'Solid', 'A bit heavy on the road.'),
    ],
  ),
  _Product(
    id: 'meridian',
    name: 'Meridian',
    category: 'lifestyle',
    label: 'Lifestyle Shoes',
    shape: 'low',
    price: 95,
    badge: 'Bestseller',
    lastPair: 'EU 41',
    description:
        'A clean leather low-top on a gum cupsole that goes with '
        'everything.',
    colorways: [
      _Colorway('white-forest', 'White/Forest', [
        '#FAFAFA',
        '#166534',
        '#F5F0E6',
        '#B45309',
        '#FAFAFA',
      ]),
      _Colorway('white-navy', 'White/Navy', [
        '#FAFAFA',
        '#1E3A8A',
        '#F5F0E6',
        '#B45309',
        '#FAFAFA',
      ]),
    ],
    reviewCount: 212,
    reviews: [
      _Review('Sofia', 5, 'Classic', 'Wear them every day.'),
      _Review('Nick', 5, 'Great value', 'Comfortable out of the box.'),
    ],
  ),
  _Product(
    id: 'harbor-low',
    name: 'Harbor Low',
    category: 'lifestyle',
    label: 'Lifestyle Shoes',
    shape: 'low',
    price: 85,
    lastPair: 'EU 45',
    gone: ['EU 39', 'EU 40'],
    description: 'Canvas and suede on a vulcanised sole, made to be worn in.',
    colorways: [
      _Colorway('navy', 'Navy/White', [
        '#1E3A5F',
        '#F8FAFC',
        '#FFFFFF',
        '#CBD5E1',
        '#F8FAFC',
      ]),
      _Colorway('black-gum', 'Black/Gum', [
        '#18181B',
        '#F4F4F5',
        '#F5F0E6',
        '#B45309',
        '#F4F4F5',
      ]),
    ],
    reviewCount: 37,
    reviews: [
      _Review('Ivy', 4, 'Nice and light', 'Good for summer.'),
      _Review('Max', 4, 'Comfy', 'Laces are a bit long.'),
    ],
  ),
  _Product(
    id: 'alto',
    name: 'Alto',
    category: 'lifestyle',
    label: 'Lifestyle Shoes',
    shape: 'low',
    price: 110,
    badge: 'Just In',
    lastPair: 'EU 42',
    description:
        'A soft knit upper and a cushioned footbed for long days on your '
        'feet.',
    colorways: [
      _Colorway('stone', 'Stone', [
        '#D6D3D1',
        '#57534E',
        '#FFFFFF',
        '#A8A29E',
        '#FAFAF9',
      ]),
      _Colorway('sage', 'Sage', [
        '#A3B18A',
        '#3F4F2F',
        '#FFFFFF',
        '#A8A29E',
        '#FAFAF9',
      ]),
    ],
    reviewCount: 19,
    reviews: [
      _Review('Rosa', 5, 'Like slippers', 'So soft, still looks smart.'),
    ],
  ),
  _Product(
    id: 'courtline-high',
    name: 'Courtline High',
    category: 'basketball',
    label: 'Basketball Shoes',
    shape: 'high',
    price: 150,
    badge: 'Bestseller',
    lastPair: 'EU 45',
    gone: ['EU 43'],
    description:
        'Ankle support and a strap that locks you in, on a grippy court '
        'outsole.',
    colorways: [
      _Colorway('white-red', 'White/Red', [
        '#FFFFFF',
        '#B91C1C',
        '#FFFFFF',
        '#111111',
        '#FFFFFF',
      ]),
      _Colorway('white-royal', 'White/Royal', [
        '#FFFFFF',
        '#1D4ED8',
        '#FFFFFF',
        '#111111',
        '#FFFFFF',
      ]),
    ],
    reviewCount: 88,
    reviews: [
      _Review('Kai', 5, 'Locked in', 'Great support on cuts.'),
      _Review('Dan', 4, 'Stiff at first', 'Breaks in after a week.'),
    ],
  ),
  _Product(
    id: 'vector-mid',
    name: 'Vector Mid',
    category: 'basketball',
    label: 'Basketball Shoes',
    shape: 'high',
    price: 125,
    lastPair: 'EU 44',
    description: 'A mid-cut for quick guards, light and low to the floor.',
    colorways: [
      _Colorway('black-gold', 'Black/Gold', [
        '#111827',
        '#F59E0B',
        '#F9FAFB',
        '#111827',
        '#F9FAFB',
      ]),
    ],
  ),
];
