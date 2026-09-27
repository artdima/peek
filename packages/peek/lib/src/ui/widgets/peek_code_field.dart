import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// Cells for a short code, typed the way a code from a text message is: the
/// keypad shows digits, each digit moves on to the next cell, Backspace goes
/// back, and a pasted or autofilled code fills every cell at once.
///
/// One invisible field lies under the cells and holds the text, so paste,
/// autofill and Backspace behave as the platform has them.
final class PeekCodeField extends StatefulWidget {
  /// Creates the cells, calling [onCompleted] once every one holds a digit.
  const PeekCodeField({
    required this.onCompleted,
    this.onChanged,
    this.length = 4,
    this.enabled = true,
    this.error = false,
    this.semanticLabel,
    super.key,
  });

  /// Called with the whole code when the last cell is filled.
  final ValueChanged<String> onCompleted;

  /// Called with the digits so far, whenever they change.
  final ValueChanged<String>? onChanged;

  /// How many digits the code has.
  final int length;

  /// Whether the code can be typed.
  final bool enabled;

  /// Whether to outline the cells in the failure colour.
  final bool error;

  /// What a screen reader calls the field.
  final String? semanticLabel;

  @override
  State<PeekCodeField> createState() => PeekCodeFieldState();
}

/// The state of a [PeekCodeField], reached through a `GlobalKey` to clear,
/// refuse or focus the code.
final class PeekCodeFieldState extends State<PeekCodeField>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  String _text = '';
  String? _completed;

  /// The digits typed so far.
  String get code => _controller.text;

  /// Empties the cells.
  void clear() => _controller.clear();

  /// Shakes the cells and empties them, for a code the other side refused.
  void reject() {
    clear();
    unawaited(_shake.forward(from: 0));
  }

  /// Puts the cursor in the cells and brings up the keypad.
  void focus() => _focus.requestFocus();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    _shake.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _changed() {
    final code = _controller.text;
    if (code == _text) return;
    setState(() => _text = code);
    widget.onChanged?.call(code);
    if (code.length < widget.length) {
      _completed = null;
    } else if (code != _completed) {
      _completed = code;
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final code = _text;
    final active = math.min(code.length, widget.length - 1);

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final offset = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: Semantics(
                container: true,
                label: widget.semanticLabel,
                child: CupertinoTextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  decoration: null,
                  showCursor: false,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < widget.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    _Cell(
                      digit: index < code.length ? code[index] : '',
                      active: _focus.hasFocus && index == active,
                      error: widget.error,
                      enabled: widget.enabled,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.digit,
    required this.active,
    required this.error,
    required this.enabled,
    required this.theme,
  });

  final String digit;
  final bool active;
  final bool error;
  final bool enabled;
  final PeekTheme theme;

  @override
  Widget build(BuildContext context) {
    final border =
        error
            ? theme.failure
            : active
            ? theme.accent
            : theme.separator;

    return Container(
      width: 48,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.radius),
        border: Border.all(color: border, width: active || error ? 2 : 1),
      ),
      child: Text(
        digit,
        style: theme.largeTitle.copyWith(
          fontSize: 26,
          color: enabled ? theme.label : theme.secondaryLabel,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
