import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listen to keydown events and dispatch them via a handler map.
/// Each entry in [keyHandlers] maps a [LogicalKeyboardKey] to a [VoidCallback].
class EHKeyboardListener extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;

  /// Maps each logical key to its handler. Keys not present in the map are ignored.
  final Map<LogicalKeyboardKey, VoidCallback> keyHandlers;

  /// Keys whose auto-repeat events should invoke the handler too.
  ///
  /// Empty by default, which preserves the original behaviour: only the initial
  /// key-down is dispatched. Used by the read page so held pan/zoom keys keep
  /// moving/zooming the image.
  final Set<LogicalKeyboardKey> repeatableKeys;

  /// Optional predicate for auto-repeat events, evaluated instead of
  /// [repeatableKeys] when provided.
  ///
  /// The read page uses it so that left/right only repeat while Ctrl is held
  /// (panning), keeping a plain held arrow a single page turn.
  final bool Function(KeyEvent event)? repeatPredicate;

  const EHKeyboardListener({
    Key? key,
    required this.child,
    required this.keyHandlers,
    this.focusNode,
    this.repeatableKeys = const <LogicalKeyboardKey>{},
    this.repeatPredicate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyRepeatEvent) {
          final bool repeatable = repeatPredicate != null ? repeatPredicate!(event) : repeatableKeys.contains(event.logicalKey);
          if (!repeatable) {
            return KeyEventResult.ignored;
          }
        } else if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        final VoidCallback? handler = keyHandlers[event.logicalKey];
        if (handler != null) {
          handler();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
