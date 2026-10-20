import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'shop_api.dart';
import 'sneaker.dart';

/// The shop's theme: black on white, or white on black.
ThemeData shopTheme(Brightness brightness) {
  final shop = brightness == Brightness.dark ? _Shop.dark : _Shop.light;
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: shop.ink,
      brightness: brightness,
      primary: shop.ink,
      onPrimary: shop.background,
      surface: shop.background,
      onSurface: shop.ink,
    ),
    scaffoldBackgroundColor: shop.background,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: shop.ink,
      actionTextColor: shop.background,
      contentTextStyle: TextStyle(fontSize: 15, color: shop.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: shop.ink),
  );
}

/// Pace, a small shop for running and court shoes: a catalogue, a page per
/// shoe, favourites and a bag that orders. Everything it shows comes from
/// a call through [api], so every screen leaves a trail in Peek.
class ShopHome extends StatefulWidget {
  /// Opens the shop over [api].
  const ShopHome({required this.api, super.key});

  /// Where the shop's data comes from.
  final ShopApi api;

  @override
  State<ShopHome> createState() => _ShopHomeState();
}

enum _Tab { shop, favourites, bag }

class _ShopHomeState extends State<ShopHome> {
  var _tab = _Tab.shop;
  var _bag = Bag.empty;
  List<Product>? _favourites;
  var _ordering = false;

  ShopApi get _api => widget.api;

  Set<String> get _kept => {
    for (final product in _favourites ?? const <Product>[]) product.id,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadBag());
    unawaited(_loadFavourites());
  }

  Future<void> _loadBag() async {
    try {
      final bag = await _api.bag();
      if (mounted) setState(() => _bag = bag);
    } on DioException catch (_) {
      // The badge waits for the next answer.
    }
  }

  Future<void> _loadFavourites() async {
    try {
      final favourites = await _api.favourites();
      if (mounted) setState(() => _favourites = favourites);
    } on DioException catch (_) {
      if (mounted) setState(() => _favourites ??= const []);
    }
  }

  void _select(_Tab tab) {
    setState(() => _tab = tab);
    if (tab == _Tab.favourites) unawaited(_loadFavourites());
    if (tab == _Tab.bag) unawaited(_loadBag());
  }

  Future<void> _open(Product product) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder:
          (_) => _ProductScreen(
            api: _api,
            product: product,
            kept: _kept.contains(product.id),
            onBag: (bag) => setState(() => _bag = bag),
            onKept: (_) => unawaited(_loadFavourites()),
            onViewBag: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              _select(_Tab.bag);
            },
          ),
    ),
  );

  Future<void> _remove(BagLine line) async {
    try {
      final bag = await _api.remove(line);
      if (mounted) setState(() => _bag = bag);
    } on DioException catch (_) {
      if (mounted) _say(context, "Couldn't remove it. Try again.");
    }
  }

  Future<void> _checkout() async {
    setState(() => _ordering = true);
    try {
      final order = await _api.order(_bag);
      if (!mounted) return;
      setState(() => _bag = Bag.empty);
      await showModalBottomSheet<void>(
        context: context,
        builder:
            (sheet) => _OrderPlaced(
              order: order,
              onDone: () {
                Navigator.of(sheet).pop();
                _select(_Tab.shop);
              },
            ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      _say(
        context,
        error.response?.statusCode == 503
            ? "Payment didn't go through. Please try again."
            : "Couldn't place the order. Try again.",
      );
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _tab.index,
      children: [
        _Catalogue(api: _api, onOpen: _open),
        _Favourites(products: _favourites, onOpen: _open),
        _BagView(
          bag: _bag,
          ordering: _ordering,
          onRemove: _remove,
          onCheckout: _checkout,
          onShop: () => _select(_Tab.shop),
        ),
      ],
    ),
    bottomNavigationBar: _NavBar(
      tab: _tab,
      inBag: _bag.lines.length,
      onSelect: _select,
    ),
  );
}

/// The shoes, by category, two to a row.
class _Catalogue extends StatefulWidget {
  const _Catalogue({required this.api, required this.onOpen});

  final ShopApi api;
  final ValueChanged<Product> onOpen;

  @override
  State<_Catalogue> createState() => _CatalogueState();
}

class _CatalogueState extends State<_Catalogue> {
  static const List<(String?, String)> _categories = [
    (null, 'All'),
    ('running', 'Running'),
    ('lifestyle', 'Lifestyle'),
    ('basketball', 'Basketball'),
  ];

  String? _category;
  List<Product>? _products;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final category = _category;
    try {
      final products = await widget.api.products(category: category);
      if (mounted && category == _category) {
        setState(() => _products = products);
      }
    } on DioException catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _pick(String? category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _products = null;
      _failed = false;
    });
    unawaited(_load());
  }

  void _retry() {
    setState(() => _failed = false);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final products = _products;
    final title = _categories.firstWhere((entry) => entry.$1 == _category).$2;
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 6,
        bottom: 24,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('PACE', style: shop.wordmark),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            products == null
                ? '$title Shoes'
                : '$title Shoes (${products.length})',
            style: shop.title,
          ),
        ),
        const SizedBox(height: 10),
        _Categories(
          categories: _categories,
          selected: _category,
          onPick: _pick,
        ),
        const SizedBox(height: 4),
        if (_failed)
          _Problem(text: "Couldn't load the shop.", onRetry: _retry)
        else if (products == null)
          const _Skeleton()
        else
          _Grid(products: products, onOpen: widget.onOpen),
      ],
    );
  }
}

/// The categories as words in a row, the chosen one underlined.
class _Categories extends StatelessWidget {
  const _Categories({
    required this.categories,
    required this.selected,
    required this.onPick,
  });

  final List<(String?, String)> categories;
  final String? selected;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: shop.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (final (id, name) in categories)
              InkWell(
                onTap: () => onPick(id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: id == selected ? shop.ink : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        name,
                        style: shop.name.copyWith(
                          fontSize: 16,
                          color: id == selected ? shop.ink : shop.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Products two to a row, edge to edge.
class _Grid extends StatelessWidget {
  const _Grid({required this.products, required this.onOpen});

  final List<Product> products;
  final ValueChanged<Product> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < products.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Tile(product: products[i], onOpen: onOpen)),
              const SizedBox(width: 4),
              Expanded(
                child:
                    i + 1 < products.length
                        ? _Tile(product: products[i + 1], onOpen: onOpen)
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ],
  );
}

/// A shoe in the grid: its picture, then what it is and what it costs.
class _Tile extends StatelessWidget {
  const _Tile({required this.product, required this.onOpen});

  final Product product;
  final ValueChanged<Product> onOpen;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final colours = product.colorways.length;
    return InkWell(
      onTap: () => onOpen(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Picture(shape: product.shape, colors: product.colorways.first),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.badge case final badge?)
                  Text(badge, style: shop.name.copyWith(color: shop.accent)),
                Text(product.name, style: shop.name),
                Text(product.label, style: shop.body),
                if (colours > 1) Text('$colours Colours', style: shop.body),
                const SizedBox(height: 6),
                Text(_price(product.price), style: shop.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A shoe on the grey of a product photo.
class _Picture extends StatelessWidget {
  const _Picture({
    required this.shape,
    required this.colors,
    this.aspectRatio = 1,
    this.inset = 14,
  });

  final SneakerShape shape;
  final Colorway colors;
  final double aspectRatio;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [shop.tileTop, shop.tileBottom],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Center(child: Sneaker(shape: shape, colors: colors.colors)),
        ),
      ),
    );
  }
}

/// Grey tiles where the shoes will be.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    Widget tile() => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1, child: ColoredBox(color: shop.field)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              width: 90,
              height: 12,
              child: ColoredBox(color: shop.field),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 28),
            child: Row(children: [tile(), const SizedBox(width: 4), tile()]),
          ),
      ],
    );
  }
}

/// Something did not load, and a way to ask again.
class _Problem extends StatelessWidget {
  const _Problem({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
      child: Column(
        children: [
          Text(text, style: shop.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _Pill(label: 'Try Again', outlined: true, onTap: onRetry),
        ],
      ),
    );
  }
}

/// One shoe: its colours, its sizes, and a way into the bag.
class _ProductScreen extends StatefulWidget {
  const _ProductScreen({
    required this.api,
    required this.product,
    required this.kept,
    required this.onBag,
    required this.onKept,
    required this.onViewBag,
  });

  final ShopApi api;
  final Product product;
  final bool kept;
  final ValueChanged<Bag> onBag;
  final ValueChanged<bool> onKept;
  final VoidCallback onViewBag;

  @override
  State<_ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<_ProductScreen> {
  late Product _product = widget.product;
  late bool _kept = widget.kept;
  var _colorway = 0;
  ShoeSize? _size;
  Reviews? _reviews;
  var _reviewsFailed = false;
  var _adding = false;

  ShopApi get _api => widget.api;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadReviews());
  }

  Future<void> _load() async {
    try {
      final product = await _api.product(_product.id);
      if (mounted) setState(() => _product = product);
    } on DioException catch (_) {
      if (mounted) _say(context, "Couldn't load the sizes.");
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _api.reviews(_product.id);
      if (mounted) setState(() => _reviews = reviews);
    } on DioException catch (_) {
      if (mounted) setState(() => _reviewsFailed = true);
    }
  }

  Future<void> _add() async {
    final size = _size;
    if (size == null) {
      _say(context, 'Select a size first.');
      return;
    }
    setState(() => _adding = true);
    try {
      final bag = await _api.add(_product, _product.colorways[_colorway], size);
      widget.onBag(bag);
      if (mounted) {
        _say(context, 'Added to Bag', action: ('View Bag', widget.onViewBag));
      }
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 409) {
        _say(context, 'Sorry, ${size.label} has just sold out.');
        setState(() => _size = null);
        unawaited(_load());
      } else {
        _say(context, "Couldn't add it to your bag. Try again.");
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _keep() async {
    final keep = !_kept;
    setState(() => _kept = keep);
    try {
      await _api.favourite(_product, keep: keep);
      widget.onKept(keep);
    } on DioException catch (_) {
      if (mounted) setState(() => _kept = !keep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final product = _product;
    final colorway = product.colorways[_colorway];
    final lastPair = [
      for (final size in product.sizes)
        if (size.lastPair && size.available) size.label,
    ];
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: 24,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: shop.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: shop.title),
                Text(product.label, style: shop.body.copyWith(fontSize: 16)),
                const SizedBox(height: 12),
                Text(_price(product.price), style: shop.name),
              ],
            ),
          ),
          _Picture(
            shape: product.shape,
            colors: colorway,
            aspectRatio: 1.05,
            inset: 24,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (index, way) in product.colorways.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _colorway = index),
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                index == _colorway
                                    ? shop.ink
                                    : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: SizedBox(
                          width: 64,
                          child: _Picture(
                            shape: product.shape,
                            colors: way,
                            inset: 5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(colorway.name, style: shop.body),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text('Select Size', style: shop.name)),
                Text('Size Guide', style: shop.body),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (product.sizes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            _Sizes(
              sizes: product.sizes,
              selected: _size,
              onPick: (size) => setState(() => _size = size),
            ),
          if (lastPair.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Only 1 left in ${lastPair.first}',
                style: shop.name.copyWith(color: shop.accent),
              ),
            ),
          if (product.description case final description?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text(description, style: shop.text),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
            child: _ReviewsView(reviews: _reviews, failed: _reviewsFailed),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: shop.background,
          border: Border(top: BorderSide(color: shop.hairline)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: _Pill(label: 'Add to Bag', busy: _adding, onTap: _add),
              ),
              const SizedBox(width: 10),
              _Round(
                icon: _kept ? Icons.favorite : Icons.favorite_border,
                tooltip: _kept ? 'Remove from Favourites' : 'Favourite',
                onTap: _keep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sizes, three to a row; the ones that are gone are greyed out.
class _Sizes extends StatelessWidget {
  const _Sizes({
    required this.sizes,
    required this.selected,
    required this.onPick,
  });

  final List<ShoeSize> sizes;
  final ShoeSize? selected;
  final ValueChanged<ShoeSize> onPick;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in sizes)
                SizedBox(
                  width: width,
                  child: Material(
                    color: size.available ? shop.background : shop.field,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color:
                            size.label == selected?.label
                                ? shop.ink
                                : shop.hairline,
                        width: size.label == selected?.label ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: size.available ? () => onPick(size) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          size.label,
                          textAlign: TextAlign.center,
                          style: shop.text.copyWith(
                            color: size.available ? shop.ink : shop.disabled,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// What reviewers think: loading, unavailable, or their words.
class _ReviewsView extends StatelessWidget {
  const _ReviewsView({required this.reviews, required this.failed});

  final Reviews? reviews;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final reviews = this.reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reviews == null ? 'Reviews' : 'Reviews (${reviews.count})',
          style: shop.name.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 10),
        if (failed)
          Text('Reviews are unavailable right now.', style: shop.body)
        else if (reviews == null)
          Text('Loading reviews…', style: shop.body)
        else ...[
          Row(
            children: [
              _Stars(rating: reviews.average, size: 18),
              const SizedBox(width: 8),
              Text(
                '${reviews.average.toStringAsFixed(1)} Stars',
                style: shop.name,
              ),
            ],
          ),
          for (final review in reviews.items)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.title, style: shop.name),
                  const SizedBox(height: 4),
                  _Stars(rating: review.rating.toDouble(), size: 14),
                  const SizedBox(height: 6),
                  Text(review.body, style: shop.text),
                  Text(review.author, style: shop.body),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Five stars, as many filled as [rating] rounds to.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            star <= rating.round() ? Icons.star : Icons.star_border,
            size: size,
            color: shop.ink,
          ),
      ],
    );
  }
}

/// The shoes kept for later.
class _Favourites extends StatelessWidget {
  const _Favourites({required this.products, required this.onOpen});

  final List<Product>? products;
  final ValueChanged<Product> onOpen;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final products = this.products;
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 18,
        bottom: 24,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text('Favourites', style: shop.title),
        ),
        if (products == null)
          const _Skeleton()
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Items added to your Favourites will be saved here.',
              style: shop.body,
            ),
          )
        else
          _Grid(products: products, onOpen: onOpen),
      ],
    );
  }
}

/// What is in the bag, what it comes to, and the way to pay.
class _BagView extends StatelessWidget {
  const _BagView({
    required this.bag,
    required this.ordering,
    required this.onRemove,
    required this.onCheckout,
    required this.onShop,
  });

  final Bag bag;
  final bool ordering;
  final ValueChanged<BagLine> onRemove;
  final VoidCallback onCheckout;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 18,
        16,
        24,
      ),
      children: [
        Text('Bag', style: shop.title),
        const SizedBox(height: 16),
        if (bag.lines.isEmpty) ...[
          Text('There are no items in your bag.', style: shop.body),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: _Pill(label: 'Shop Now', outlined: true, onTap: onShop),
          ),
        ] else ...[
          for (final line in bag.lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: _Picture(
                    shape: line.shape,
                    colors: line.colorway,
                    inset: 8,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: shop.name),
                      Text(line.label, style: shop.body),
                      Text(line.colorway.name, style: shop.body),
                      Text('Size ${line.size}', style: shop.body),
                      const SizedBox(height: 8),
                      Text(_price(line.price), style: shop.name),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => onRemove(line),
                  icon: Icon(Icons.close, color: shop.secondary, size: 20),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: shop.hairline),
              ),
            ),
          ],
          _SumRow(label: 'Subtotal', value: _price(bag.total)),
          const _SumRow(label: 'Delivery', value: 'Free'),
          const SizedBox(height: 10),
          _SumRow(label: 'Total', value: _price(bag.total), strong: true),
          const SizedBox(height: 24),
          _Pill(label: 'Checkout', busy: ordering, onTap: onCheckout),
        ],
      ],
    );
  }
}

/// One line of the sum: a label and an amount at the far end.
class _SumRow extends StatelessWidget {
  const _SumRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final style = strong ? shop.name : shop.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// The order went through: what was ordered and when it comes.
class _OrderPlaced extends StatelessWidget {
  const _OrderPlaced({required this.order, required this.onDone});

  final Order order;
  final VoidCallback onDone;

  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final arrives = order.arrives;
    final date =
        '${_days[arrives.weekday - 1]} ${arrives.day} '
        '${_months[arrives.month - 1]}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: shop.ink, size: 40),
          const SizedBox(height: 16),
          Text('Thanks for your order', style: shop.title),
          const SizedBox(height: 8),
          Text('Order ${order.id} · Arrives by $date', style: shop.body),
          Text('Total ${_price(order.total)}', style: shop.body),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _Pill(label: 'Continue Shopping', onTap: onDone),
          ),
        ],
      ),
    );
  }
}

/// Shop, Favourites and Bag along the bottom, with how many pairs are in
/// the bag.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.tab,
    required this.inBag,
    required this.onSelect,
  });

  final _Tab tab;
  final int inBag;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    Widget item(_Tab target, IconData icon, IconData chosen, String label) {
      final selected = target == tab;
      final color = selected ? shop.ink : shop.secondary;
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(target),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: target == _Tab.bag && inBag > 0,
                  label: Text('$inBag'),
                  backgroundColor: shop.ink,
                  textColor: shop.background,
                  child: Icon(selected ? chosen : icon, color: color, size: 26),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: shop.small.copyWith(color: color, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: shop.background,
        border: Border(top: BorderSide(color: shop.hairline)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            item(
              _Tab.shop,
              Icons.storefront_outlined,
              Icons.storefront,
              'Shop',
            ),
            item(
              _Tab.favourites,
              Icons.favorite_border,
              Icons.favorite,
              'Favourites',
            ),
            item(
              _Tab.bag,
              Icons.shopping_bag_outlined,
              Icons.shopping_bag,
              'Bag',
            ),
          ],
        ),
      ),
    );
  }
}

/// The shop's button: a full pill, black on white, or outlined.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    final ink = outlined ? shop.ink : shop.background;
    return Material(
      color: outlined ? Colors.transparent : shop.ink,
      shape: StadiumBorder(
        side: outlined ? BorderSide(color: shop.hairline) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          child: Row(
            mainAxisSize: outlined ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                )
              else
                Text(
                  label,
                  style: shop.name.copyWith(fontSize: 16, color: ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round outlined button with a glyph in it.
class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shop = _Shop.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: shop.hairline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 52,
            child: Icon(icon, color: shop.ink, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Says [text] at the bottom of the screen, with an [action] to take.
void _say(BuildContext context, String text, {(String, VoidCallback)? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: switch (action) {
          (final label, final onPressed) => SnackBarAction(
            label: label,
            onPressed: onPressed,
          ),
          null => null,
        },
      ),
    );
}

String _price(int dollars) => '\$$dollars';

/// The shop's colours and type, light or dark.
enum _Shop {
  light(
    background: Color(0xFFFFFFFF),
    tileTop: Color(0xFFEDEDED),
    tileBottom: Color(0xFFF7F7F7),
    field: Color(0xFFF5F5F5),
    ink: Color(0xFF111111),
    secondary: Color(0xFF707072),
    hairline: Color(0xFFE5E5E5),
    accent: Color(0xFFD33918),
    disabled: Color(0xFFBEBEC0),
  ),
  // The shoes stand on the grey of a product photo in both brightnesses: a
  // photo does not change with the theme, and a black shoe needs the grey.
  dark(
    background: Color(0xFF000000),
    tileTop: Color(0xFFDADADA),
    tileBottom: Color(0xFFE8E8E8),
    field: Color(0xFF1C1C1E),
    ink: Color(0xFFFFFFFF),
    secondary: Color(0xFF9E9EA0),
    hairline: Color(0xFF2C2C2E),
    accent: Color(0xFFFF6A3D),
    disabled: Color(0xFF4A4A4C),
  );

  const _Shop({
    required this.background,
    required this.tileTop,
    required this.tileBottom,
    required this.field,
    required this.ink,
    required this.secondary,
    required this.hairline,
    required this.accent,
    required this.disabled,
  });

  static _Shop of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  final Color background;
  final Color tileTop;
  final Color tileBottom;
  final Color field;
  final Color ink;
  final Color secondary;
  final Color hairline;
  final Color accent;
  final Color disabled;

  TextStyle get wordmark => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.5,
    color: ink,
  );

  TextStyle get title => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    height: 1.25,
    color: ink,
  );

  TextStyle get name => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: ink,
  );

  TextStyle get body => TextStyle(fontSize: 15, height: 1.4, color: secondary);

  TextStyle get text => TextStyle(fontSize: 15, height: 1.5, color: ink);

  TextStyle get small =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary);
}
