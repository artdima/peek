import 'dart:convert';

import 'package:meta/meta.dart';

/// What a node of a JSON document holds.
enum PeekJsonKind {
  /// A map of names to values.
  object,

  /// A list of values.
  array,

  /// Text.
  string,

  /// A number.
  number,

  /// `true` or `false`.
  boolean,

  /// `null`.
  nothing,
}

/// One value of a JSON document, with the path that leads to it.
///
/// Paths read the way they would be written in code — `data.items[3].id` —
/// so one can be copied out of the tree and pasted into a debugger.
@immutable
final class PeekJsonNode {
  /// Creates a node; [children] are empty for anything but an object or
  /// an array.
  const PeekJsonNode({
    required this.path,
    required this.kind,
    required this.value,
    this.name,
    this.index,
    this.children = const [],
  });

  /// Builds the tree of [value], which must be decoded JSON.
  factory PeekJsonNode.of(Object? value, {String path = '', String? name}) {
    final kind = _kindOf(value);
    return PeekJsonNode(
      path: path,
      name: name,
      kind: kind,
      value: value,
      children: switch (value) {
        final Map<String, dynamic> map => [
          for (final MapEntry(:key, value: child) in map.entries)
            PeekJsonNode.of(
              child,
              path: path.isEmpty ? key : '$path.$key',
              name: key,
            ),
        ],
        final List<dynamic> list => [
          for (final (index, child) in list.indexed)
            PeekJsonNode._indexed(child, '$path[$index]', index),
        ],
        _ => const [],
      },
    );
  }

  factory PeekJsonNode._indexed(Object? value, String path, int index) {
    final node = PeekJsonNode.of(value, path: path);
    return PeekJsonNode(
      path: node.path,
      kind: node.kind,
      value: node.value,
      index: index,
      children: node.children,
    );
  }

  /// Decodes [source] and builds its tree, or returns `null` when it is
  /// not JSON after all.
  static PeekJsonNode? tryParse(String source) {
    try {
      return PeekJsonNode.of(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  /// How to reach this node from the root; empty at the root.
  final String path;

  /// The name this node has in its parent object.
  final String? name;

  /// The place this node has in its parent array.
  final int? index;

  /// What it holds.
  final PeekJsonKind kind;

  /// The decoded value itself.
  final Object? value;

  /// What is inside, for an object or an array.
  final List<PeekJsonNode> children;

  /// Whether this node has anything inside it.
  bool get isBranch =>
      kind == PeekJsonKind.object || kind == PeekJsonKind.array;

  /// How many values are inside.
  int get count => children.length;

  /// The paths of every object and array in this tree, this one included.
  Set<String> get branchPaths {
    final paths = <String>{};
    void walk(PeekJsonNode node) {
      if (!node.isBranch) return;
      paths.add(node.path);
      node.children.forEach(walk);
    }

    walk(this);
    return paths;
  }

  /// The rows to draw, given which branches are open.
  List<PeekJsonRow> rows(Set<String> expanded) {
    final rows = <PeekJsonRow>[];
    void walk(PeekJsonNode node, int depth) {
      rows.add(PeekJsonRow(node: node, depth: depth));
      if (!node.isBranch || !expanded.contains(node.path)) return;
      for (final child in node.children) {
        walk(child, depth + 1);
      }
    }

    walk(this, 0);
    return rows;
  }

  /// The branches that have to be open for every match of [needle] to be
  /// in view, matching names and scalar values, ignoring case.
  Set<String> pathsTo(String needle) {
    final wanted = needle.trim().toLowerCase();
    if (wanted.isEmpty) return const {};
    final paths = <String>{};

    bool walk(PeekJsonNode node, List<String> ancestors) {
      final found =
          (node.name?.toLowerCase().contains(wanted) ?? false) ||
          (!node.isBranch && node.text.toLowerCase().contains(wanted));
      var any = found;
      if (node.isBranch) {
        final deeper = [...ancestors, node.path];
        for (final child in node.children) {
          if (walk(child, deeper)) any = true;
        }
      }
      if (any) paths.addAll(ancestors);
      return any;
    }

    walk(this, const []);
    return paths;
  }

  /// Whether this node, by name or by value, matches [needle].
  bool matches(String needle) {
    final wanted = needle.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    return (name?.toLowerCase().contains(wanted) ?? false) ||
        (!isBranch && text.toLowerCase().contains(wanted));
  }

  /// The scalar as it reads in JSON: text in quotes, everything else bare.
  String get text => switch (kind) {
    PeekJsonKind.string => '"$value"',
    PeekJsonKind.nothing => 'null',
    PeekJsonKind.object => '{…}',
    PeekJsonKind.array => '[…]',
    _ => '$value',
  };

  /// This node and everything under it, as JSON again.
  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(value);

  @override
  String toString() => 'PeekJsonNode(${path.isEmpty ? 'root' : path})';

  static PeekJsonKind _kindOf(Object? value) => switch (value) {
    null => PeekJsonKind.nothing,
    Map<String, dynamic>() => PeekJsonKind.object,
    List<dynamic>() => PeekJsonKind.array,
    String() => PeekJsonKind.string,
    num() => PeekJsonKind.number,
    bool() => PeekJsonKind.boolean,
    _ => PeekJsonKind.string,
  };
}

/// A node at the depth it is drawn.
@immutable
final class PeekJsonRow {
  /// Creates a row for [node] at [depth].
  const PeekJsonRow({required this.node, required this.depth});

  /// What to draw.
  final PeekJsonNode node;

  /// How far in, in levels.
  final int depth;
}
