# Animation and scroll notes

Notes on the decisions behind the header, written for the follow-up technical
discussion.

## How the reference was read

The reference recording was decomposed into contact sheets to find the
transitions, then into native-framerate strips around each one, and finally
into full-resolution frames of the three resting states. Proportions in
`ProfileMetrics` come from measuring those frames and converting to logical
pixels; they are written as named constants so they can be re-tuned in one
place.

The single most important thing that reading the video changed: **the
full-bleed cover is not the resting state.** The app rests on the
circular-avatar state, and the cover opens only when the list is pulled down
past its top.

## Scroll model

```
scroll offset      0 ─────────── galleryRange ──────────────────► maxScroll
header extent  expandedExtent   restingExtent              collapsedExtent
state            cover open        at rest                   pinned app bar
                 (pull down)                                (scrolled away)
```

The page is a `NestedScrollView`: the header, the information card and the
pinned tab strip are outer slivers, and each tab (Posts / Archived) is its own
inner `CustomScrollView` inside a `TabBarView`, so the two grids keep separate
scroll positions and can be swiped between. The header and the tab strip are
grouped in a `SliverMainAxisGroup` under one `SliverOverlapAbsorber`;
`PinnedObstruction` reports their combined pinned height, which the group does
not do on its own.

`HeaderSnapCoordinator` listens for `ScrollEndNotification` and animates to
whichever end of the current transition is closer: the open cover or the
resting state inside the gallery range, the resting state or the finished
swallow inside the swallow range. A released half-gesture therefore never
leaves the header frozen mid-morph. The animation is started from a microtask
so it is not kicked off inside the notification dispatch that ended the
previous scroll activity.

`NestedScrollView` does not apply a header stretch configuration, so
`ProfileScrollCoordinator` tracks the overscroll past the open cover itself
(capped at `ProfileMetrics.maxStretch`) and feeds it to the header as extra
extent; `HeaderGeometry` hands that extent to the photo so it grows with the
pull instead of leaving a gap under it. The same coordinator works out when
the outer list and the visible tab have both reached their end, and publishes
both values through `ValueNotifier`s, so `ProfileScreen` itself holds no
per-scroll state.

`ProfileScrollPhysics` floors ballistic simulations at the resting offset
whenever a fling starts below it. Without that, a hard flick back to the top
would sail into the gallery range and leave the cover open. Dragging is left
alone, so the deliberate pull that is supposed to open the gallery still does.

## Why `SliverPersistentHeader` and not a scroll listener

A listener driving `setState` would rebuild the whole page on every scrolled
pixel. The sliver protocol already delivers the header's current extent during
layout, which is both cheaper and a frame earlier.

The delegate's `build` returns a `LayoutBuilder` and reads
`constraints.maxHeight` rather than the `shrinkOffset` argument, because
`shrinkOffset` does not account for the overscroll stretch.

## Rebuild budget during scrolling

Everything expensive is built **once** into `_HeaderParts`, cached on the
sliver's state and shared by every delegate: the cover
`Image`, its blurred copy, the background, the action row, the app bar icons,
the name row and the status line. Per frame the delegate only recreates the
cheap positioning widgets around them (`Positioned`, `Opacity`, `Transform`,
`ClipRRect`, `Align`). Because the child widget instances are identical
between frames, `Element.updateChild` short-circuits and none of those
subtrees rebuild.

* The name is laid out once at 24px and **scaled with a transform**, never by
  animating `fontSize`, so the paragraph is not re-shaped on every frame.
* The status line swaps to the story count through a `ValueListenable` owned
  by `ProfileScrollCoordinator`, so the swap never invalidates the header
  delegate.

Scroll position deliberately does not live in `ProfileController`. Scrolling
therefore never notifies it and never rebuilds the screen.

Elsewhere: each grid tile gets its own `RepaintBoundary` from the grid's
builder delegate, the frosted controls clip their `BackdropFilter` to their
own rounded rect and share one backdrop capture per `BackdropGroup` (the
header's action row, and the shell's floating controls). The overscroll
stretch rebuilds only the delegate: the header's subtrees are cached in
`_HeaderParts` on the sliver's state, and the release is a 240 ms
`AnimationController` rather than a frame count.

* **Blur only where it shows.** The action row blurs its backdrop only while
  the cover photo is behind it (`galleryProgress > 0`); over the flat header
  gradient it draws the tint alone. Frosted surfaces are never wrapped in an
  `Opacity` (the layer would hide the real backdrop from the filter); they
  fade through `FrostedSurface.opacity`, which scales tint, border and blur.
* **One decode per image.** `MediaImages` gives the grid, the preview and the
  precache the same `ResizeImage` key, sized to the larger of the tile and
  the preview card, so each asset is decoded once and never at 1080x1920.
  Only the first screenful of each tab (`gridColumnCount * 4` items) is
  precached; the rest decode lazily as the grid builds their tiles.
* **The swallow is one painter.** `SwallowedAvatar` draws hole, neck and
  avatar as one clockwise path (non-zero fill gives the union without
  `Path.combine`), and fills the photo through an `ImageShader` inside one
  clip to that outline. The photo's blur (which builds up from the moment
  the avatar heads for the hole) and its fade share a single `saveLayer`
  bounded to the avatar, instead of an `ImageFiltered` over the whole header.
* **The swallow is a transition, not a stop.** Released part-way, the
  avatar is swallowed if it is nearer the hole than its resting place and
  let back out otherwise (`ProfileScrollPhysics.swallowSnapTarget`, with
  `HeaderSnapCoordinator` catching anything that stops inside the range).
* **The preview blurs once.** One full-screen filter at a fixed sigma; only
  the dimming animates. The menu has no filter of its own because it
  already sits on the blurred page.
* **The notice joins the floating group.** Every message shows
  `FloatingNotice`, a frosted card stacked above the add-post slot, instead
  of a Material `SnackBar`. The shell owns its `NoticeController` and hands
  it down through `NoticeScope`; the post preview is a separate route, so it
  reports the chosen menu entry back to the page once it has closed. The card
  shares the shell's backdrop capture and fades through
  `FrostedSurface.opacity`.
* **Tab switches stay local.** `ProfileController` notifies only on data
  changes; the tab lives in `tabListenable`, so switching tabs never rebuilds
  the shell or the grids.

## The morph itself

`HeaderGeometry.resolve(metrics, extent)` is a pure function: one input, and
every animated value falls out of it. Two progress values, mutually
exclusive:

| | range | drives |
|---|---|---|
| `galleryProgress` | resting extent -> expanded extent | circle-to-cover morph, name slide to bottom-left, cover blur, story bar |
| `dockProgress` | resting extent -> collapsed extent | swallow into the black hole, name docking, action row collapse |

Phase table:

| Stage | Range | Behaviour |
|---|---|---|
| Cover morph | `gallery` 0 -> 1 | The rect follows a quadratic curve (`easeInOutSine` parameter) from the circle towards a rounded square under the status bar and on to the full-bleed cover, so it grows as a square first and widens last, with no stage boundary. Corners soften from a circle to `coverCornerRadius` over 0.08 -> 0.5 and square off over 0.7 -> 1. |
| Cover blur | `gallery` 0.4 -> 1 | A 96px copy of the cover, blurred once when the photo decodes (`bakeBlurredCover`), fades in over the sharp photo through a `ShaderMask` gradient: transparent down to the name, `easeInOutSine` to full strength at the bottom edge. The fade-in opacity is folded into the gradient's alpha, so no blur runs during the scroll and it costs one mask layer. |
| Name to cover | `gallery` 0 -> 1 | `easeInOutCubic` on position, scale 0.83 -> 1.0, alignment centre -> left. |
| Approach | `swallow` 0 -> 1 | A small dot appears at the top centre (0 -> 0.25). The avatar rises, shrinks and blurs along one `easeInOutSine`/`easeInCubic` curve the whole way. |
| Hole opens | `swallow` 0.3 -> 0.65 | The dot grows into the hole and sinks a little towards the avatar. |
| Thread to belly | `swallow` 0.45 -> 0.85 | `SwallowedAvatar` joins hole and avatar with a metaball neck. It starts as a thin thread filled with the photo's own colours (its top slice smeared upwards) and widens into the hole's black belly, whose black caps the photo as it sinks inside. |
| Hole closes | `swallow` 0.85 -> 1 | The photo fades and what is left shrinks with the closing hole. |
| Action row | `dock` 0.5 -> 0.95 | Anchored to the header's bottom edge in every state; it only squashes and fades once the avatar is gone. |
| Name docking | `dock` 0 -> 1 | Vertical position follows the scroll and clamps at the app bar; the slide to the left is eased over `dock` 0.08 -> 0.7. |

`swallow` is `dock` mapped over `0 -> HeaderGeometry.swallowEnd`. `phase(t,
start, end)` in `core/helpers/phase.dart` is the only mechanism used to
express those sub-ranges, which keeps every stage independently tuneable.

## Responsiveness

No widget reads a device coordinate. `ProfileMetrics` takes the viewport size,
the system insets and the text scale factor, and derives everything else:

* avatar diameter is `21.5%` of width, also capped at `16%` of height and
  clamped to `56..112`, so a landscape viewport does not get a 180dp circle
* vertical gaps scale with a `tightness` factor (`height / 780`, clamped
  `0.62..1`) so the resting header never swallows a short or landscape screen
* the expanded cover is square on a phone, capped at `52%` of height (or
  `74%` in landscape)
* the text-scale factor is folded into the name block's height so a user with
  large text does not get a clipped header
* the floating controls are positioned from the same metrics
  (`navBottom`, `floatingStackBottom`), and each grid ends with a
  `SliverPadding` of `floatingControlsClearance`, so the last row always
  scrolls clear of the bar and the add-post button at any inset or text scale
* Android reports a 0x0 window on the first frame; `ProfileScreen` re-anchors
  the scroll offset once a real size arrives

Because the metrics object is value-equal, rotating the device produces a new
one, the delegate's `shouldRebuild` returns true, and the header re-derives
itself from the new geometry.

## Header colours

The header is a fixed blue gradient (`AppColors.headerTop` /
`headerBottom`) with a radial light (`headerGlow`) centred behind the resting
avatar, matching the reference. Once the page is scrolled to its very end
(the moment the status line switches to "N stories"), a page-coloured layer
fades in over it, so the collapsed bar blends into the content; scrolling
back fades the blue in again. The layer is driven by the same
`ValueListenable` as the status swap, so only that layer rebuilds.

## Performance invariants

The rebuild and paint invariants are encoded as widget tests in
`test/performance_test.dart`:

* the grid stays lazy mid-fling
* every on-screen tile is its own `RepaintBoundary`, with no second one inside
* the frosted surfaces clip their `BackdropFilter` to their own layer
* scrolling does not reconstruct `ProfileHeaderSliver`
* stretching the cover reuses the cached header parts
* the cover blur is baked into a small image
* the action row blurs only over the cover, and fades with no `Opacity`
* the swallow paints with no `ClipPath`, `ClipOval` or `ImageFiltered`
* switching tabs does not rebuild the shell
