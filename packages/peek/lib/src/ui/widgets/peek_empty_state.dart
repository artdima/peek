import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// What fills the screen when there is nothing to show.
final class PeekEmptyState extends StatelessWidget {
  /// Creates an empty state reading [title] over [message], under an icon.
  const PeekEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  }) : illustration = null;

  /// Creates an empty state under [illustration], the way a whole screen
  /// is left empty: a picture rather than an icon, and larger type.
  const PeekEmptyState.illustrated({
    required this.title,
    required this.message,
    required Widget this.illustration,
    this.action,
    super.key,
  }) : icon = Icons.inbox_outlined;

  /// The headline.
  final String title;

  /// The line explaining what to do.
  final String message;

  /// The icon above the headline, where there is no [illustration].
  final IconData icon;

  /// The picture above the headline, in place of [icon].
  final Widget? illustration;

  /// An optional button below the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final muted = theme.secondaryLabel;
    final illustration = this.illustration;
    final hero = illustration != null;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.gutter * 2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hero) illustration else Icon(icon, size: 40, color: muted),
              SizedBox(height: hero ? 24 : theme.gutter),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    hero
                        ? theme.headline.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        )
                        : theme.headline,
              ),
              SizedBox(height: hero ? 8 : theme.rowSpacing / 2),
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    hero
                        ? theme.body.copyWith(
                          fontSize: 17,
                          height: 1.3,
                          color: muted,
                        )
                        : theme.footnote.copyWith(color: muted),
              ),
              if (action case final widget?) ...[
                SizedBox(height: hero ? 24 : theme.gutter),
                widget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
