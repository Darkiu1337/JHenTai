# photo_view (vendored)

This is a vendored copy of [`jiangtian616/photo_view@1fecde37`](https://github.com/jiangtian616/photo_view/tree/1fecde37),
which is `photo_view` 0.14.0 plus ctrl+scroll zoom and a rewritten double
tap / tap-drag gesture. It lives in this repository so the reader can tune the
zoom behaviour; the app depends on it with a `path:` dependency.

Upstream is MIT licensed (see `LICENSE`).

## Local changes

- `lib/src/controller/photo_view_controller_delegate.dart`
  - `scale`: a scale that already lives on the controller always wins. The
    library only derives the starting scale from the scale state when the
    controller has no scale yet, which lets the reader seed a page's zoom and
    position before its `PhotoView` mounts (and keeps the zoom across resizes).
- `lib/src/core/photo_view_core.dart`
  - `_handleCtrlScrollZoom`: one multiplicative step per scroll event
    (`ctrlScrollZoomFactor`), applied immediately instead of tweening.
  - `onZoomUpdate`: tap-drag sensitivity is 1.2 scale units per screen height
    (upstream used a hard-coded 5).
  - `nextScaleState`: double tap steps by ×1.5 and returns to the initial size
    when zoomed, instead of jumping straight to `maxScale`.

Keep these in sync with the reader when updating `photo_view`.
