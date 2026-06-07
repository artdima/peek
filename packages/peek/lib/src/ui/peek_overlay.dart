import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../core/model/peek_entry.dart';
import '../core/peek.dart';
import '../core/store/peek_store.dart';
import 'peek_navigation.dart';
import 'peek_share.dart';
import 'peek_strings.dart';
import 'screens/peek_screen.dart';
import 'theme/peek_theme.dart';

/// A draggable button floating over the app that opens Peek.
///
/// Wrap the app with it once:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => PeekOverlay(
///     enabled: kDebugMode,
///     child: child!,
///   ),
/// );
/// ```
///
/// The button carries a badge counting failed and still-running calls, and
/// hides itself while a [PeekScreen] is open. It is only as wide as it
/// looks: taps anywhere else reach the app underneath.
///
/// Prefer a gesture instead of a button? Peek brings no shake detector of
/// its own; wire a package such as `shake` to [showPeek] and leave
/// [enabled] off.
final class PeekOverlay extends StatefulWidget {
  /// Creates the overlay over [child].
  const PeekOverlay({
    required this.child,
    this.peek,
    this.enabled = true,
    this.alignment = Alignment.bottomRight,
    this.strings = const PeekStrings(),
    this.share,
    super.key,
  });

  /// The app the button floats over.
  final Widget child;

  /// Which instance to watch and open; [Peek.instance] when omitted.
  final Peek? peek;

  /// Whether the button is there at all. When `false` the overlay costs
  /// nothing: [child] is returned untouched.
  final bool enabled;

  /// Where the button rests before it is dragged.
  final Alignment alignment;

  /// The words to show.
  final PeekStrings strings;

  /// What hands an export to the platform; see [PeekScreen.share].
  final PeekShareDelegate? share;

  /// How wide and tall the button's tap target is.
  static const double buttonSize = 52;

  @override
  State<PeekOverlay> createState() => _PeekOverlayState();
}

class _PeekOverlayState extends State<PeekOverlay> {
  static const double _margin = 12;

  StreamSubscription<PeekStoreChange>? _changes;
  Peek? _peek;
  Offset? _position;
  int _errors = 0;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(PeekOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled && widget.peek == oldWidget.peek) {
      return;
    }
    unawaited(_changes?.cancel());
    _changes = null;
    _bind();
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  void _bind() {
    if (!widget.enabled) {
      _peek = null;
      return;
    }
    final peek = _peek = widget.peek ?? Peek.instance;
    final counts = _count(peek);
    _errors = counts.errors;
    _pending = counts.pending;
    _changes = peek.store.changes.listen((_) => _refresh());
  }

  void _refresh() {
    final peek = _peek;
    if (peek == null || !mounted) return;
    final (:errors, :pending) = _count(peek);
    if (errors == _errors && pending == _pending) return;
    setState(() {
      _errors = errors;
      _pending = pending;
    });
  }

  static ({int errors, int pending}) _count(Peek peek) {
    var errors = 0;
    var pending = 0;
    for (final entry in peek.store.entries) {
      if (entry.isError) {
        errors++;
      } else if (entry.state == PeekEntryState.pending) {
        pending++;
      }
    }
    return (errors: errors, pending: pending);
  }

  Offset _resolve(Size area) {
    final field = (Offset.zero & area).deflate(_margin);
    const size = PeekOverlay.buttonSize;
    final left = field.left;
    final top = field.top;
    final right = math.max(left, field.right - size);
    final bottom = math.max(top, field.bottom - size);
    final current = _position;
    if (current == null) {
      final resting = widget.alignment.inscribe(const Size.square(size), field);
      return Offset(
        resting.left.clamp(left, right),
        resting.top.clamp(top, bottom),
      );
    }
    return Offset(current.dx.clamp(left, right), current.dy.clamp(top, bottom));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final position = _resolve(constraints.biggest);
                return Stack(
                  children: [
                    Positioned(
                      left: position.dx,
                      top: position.dy,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: PeekScreen.isOpen,
                        builder:
                            (context, open, _) =>
                                open
                                    ? const SizedBox.shrink()
                                    : _button(constraints.biggest),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _button(Size area) {
    final theme = PeekTheme.of(context);
    final badge = _errors > 0 ? _errors : _pending;
    final badgeColor = _errors > 0 ? theme.serverError : theme.pending;

    return GestureDetector(
      onTap: _open,
      onPanUpdate:
          (details) =>
              setState(() => _position = _resolve(area) + details.delta),
      child: Semantics(
        button: true,
        label: widget.strings.openPeek,
        child: SizedBox(
          width: PeekOverlay.buttonSize,
          height: PeekOverlay.buttonSize,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.visibility,
                    size: 22,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: _OverlayBadge(count: badge, color: badgeColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open() => unawaited(
    showPeek(
      context,
      peek: widget.peek,
      strings: widget.strings,
      share: widget.share,
    ),
  );
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: theme.background, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: theme.caption.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
