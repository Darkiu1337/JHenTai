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
  /// key-down is dispatched. Used by the read page so held pan keys keep moving
  /// the zoomed image.
  final Set<LogicalKeyboardKey> repeatableKeys;

  const EHKeyboardListener({
    Key? key,
    required this.child,
    required this.keyHandlers,
    this.focusNode,
    this.repeatableKeys = const <LogicalKeyboardKey>{},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyRepeatEvent) {
          if (!repeatableKeys.contains(event.logicalKey)) {
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
