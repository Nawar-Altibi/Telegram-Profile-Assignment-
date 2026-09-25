# Telegram Profile UI Recreation

Flutter recreation of the Telegram profile screen for the AiCon Solutions
technical assignment: a scroll-driven morphing header, a pinned segment
selector, a lazily built two-column media grid, and floating translucent
controls that the content scrolls behind.

Built with the Flutter SDK and `dart:ui` only. There are **no third-party
runtime dependencies** and no ready-made UI packages.

## Requirements


|               |                                                                         |
| ------------- | ----------------------------------------------------------------------- |
| Flutter       | **3.41.6** (stable channel)                                             |
| Dart          | 3.11.4 (bundled with Flutter 3.41.6)                                    |
| Android       | Flutter's default `minSdk`; developed on a Pixel 8 Pro emulator, API 36 |
| Other targets | Also builds for iOS and Windows desktop                                 |


The Dart constraint in `pubspec.yaml` is `^3.11.4`, so an older Flutter SDK
will stop at `flutter pub get`. Check your version with `flutter --version`
and upgrade with `flutter upgrade` if needed.

## Setup

```bash
git clone <repository-url>   # or unzip the submission
cd telegram_profile
flutter pub get
```

No API keys, backend or extra configuration are needed. All data and images
are local.

## Run

> **Run in profile mode for the real experience:**
>
> ```bash
> flutter run --profile
> ```
>
> Debug mode (`flutter run`) runs the Dart code unoptimised with extra
> checks, so scrolling and the header animations will stutter there. That
> is expected in debug and is not how the app performs. Profile mode is
> compiled like a release build and is how the smoothness was measured.
> It needs a physical device or an emulator, not a web browser.

Other commands:

```bash
flutter run              # debug mode: hot reload, but not representative of smoothness
flutter run --release    # release build
flutter test             # 60 widget and unit tests, including performance invariants
flutter analyze          # static analysis (currently no issues)
```

To check frame timing yourself, press `P` in a running `--profile` session to
toggle the performance overlay, or open Flutter DevTools from the link it
prints.

## What it does

- **Three header states, one continuous animation.** The screen opens on the
resting state: circular avatar and centred name. Scrolling up collapses the
header into a pinned app bar with the name docked at the top, while a black
hole at the top of the screen swallows the photo. The photo stretches into
a liquid neck and blurs progressively as it sinks in. Pulling the list
*down* past its top opens the full-width cover photo: the circle grows,
its corners relax into a full-width photo, and a progressive blur rises
from the bottom edge up to the name.
- **Snap on release.** Letting go part-way through either transition
finishes it or undoes it, whichever end is closer. A half-open cover opens
or closes. A half-swallowed avatar is swallowed if it is nearer the hole
and returns to its resting place otherwise.
- **Overscroll stretch.** Pulling past the open cover stretches the photo.
- **Pinned segment selector.** Posts / Archived Posts sticks under the app
bar while the information card and the grid scroll behind it. The two tabs
keep separate scroll positions and can be swiped between.
- **Media grid.** Two columns on a phone (three or four on wider screens),
built lazily from the model list, with photo
and video tiles, view counts and video durations. Tapping a tile opens it
in a preview.
- **Tap the avatar to open the cover.** Tapping the circular avatar morphs
it smoothly into the full-width cover photo, the same animation as pulling
down. Tapping the photo once it is already open does nothing.
- **Floating controls.** "Add a post" and the bottom navigation bar are
frosted glass, and the grid scrolls visibly behind them. The grid ends
with enough room that its last row always scrolls clear of them.
- **One notice style.** Every message in the app (other navigation tabs,
the header buttons, the preview menu, copying a field) appears as the same
small frosted card above the floating controls, with an icon, a title and a
short line, and hides itself after a moment.
- **Long press to copy.** Phone, bio and username copy on a long press; the
birthday does not.
- **Per-field text direction.** The Arabic bio is laid out right to left and
the Latin fields left to right. The direction is resolved from the text
itself, not hardcoded.
- **Responsive.** Every size is derived from the screen size, system insets
and text scale (see `ProfileMetrics`), with no device-specific coordinates.



## Project structure

```
lib/
  main.dart                          edge-to-edge setup, app entry
  app/app.dart                       MaterialApp and theme wiring
  core/
    constants/app_durations.dart     shared animation durations
    constants/theme/                 colours, text styles, ThemeData
    widgets/                         FrostedSurface (shared blur surface), FloatingNotice
    helpers/phase.dart               maps a sub-range of a progress value to 0..1
    utils/                           count, date and text-direction formatting
  features/
    profile/
      enums/                         MediaKind, ProfileTab
      data/
        data_sources/                in-memory mock data
        dtos/                        raw data shapes
        repositories/                DTO -> view model, all formatting
      presentation/
        controller/
          profile_controller.dart      ChangeNotifier: profile, selected tab, media
        layout/
          profile_metrics.dart         every dimension, derived from the screen
          header_geometry.dart         header extent -> position/size/opacity of each part
          media_images.dart            one shared decode size per image
        scroll/
          profile_scroll_coordinator.dart  overscroll stretch and page-end state
          header_snap_coordinator.dart settles a half-finished cover pull or swallow
          profile_scroll_physics.dart  fling rules for the resting and swallow states
        view_models/                   presentation-ready models
        screens/
          profile_screen.dart          NestedScrollView with header, card, tabs, grids
          story_preview.dart           story / media preview overlay
        widgets/
          header/                      morphing header, swallowed avatar, cover blur
          info/                        information card and its rows
          tabs/                        pinned Posts / Archived Posts selector
          grid/                        tab page, lazy media grid, tiles, badges
          empty/                       empty-tab states
    shell/
      presentation/
        screens/app_shell.dart         profile page + floating controls
        widgets/                       bottom nav, add-post button
assets/images/                       avatar.jpg, post_1.jpg .. post_5.jpg
test/                                widget, responsive and performance tests
```

The layout follows the structure suggested in the assignment. Suggested
folders with nothing to hold in this project (`networking`, `builders`,
`extensions`, `navigation`, `l10n`, `assets/icons`, `assets/fonts`) are left
out instead of being kept as empty placeholders. Icons come from Material
Icons and text uses the platform font.

## Assets

All images used by the app are in `assets/images/` and are registered in
`pubspec.yaml`:


| File                         | Used for                                      |
| ---------------------------- | --------------------------------------------- |
| `avatar.jpg`                 | profile photo, cover photo, bottom-bar avatar |
| `post_1.jpg` .. `post_5.jpg` | media grid tiles and story previews           |




## Data

All content is local mock data in
`features/profile/data/data_sources/local_profile_data_source.dart`. Grid
tiles are generated from that list; no post is written out as a widget.

Formatting is derived, not stored: view counts are compacted (`8.2K`), clip
durations are formatted from seconds, and the age in the birthday field is
computed from the date, so the card never goes out of date.

## Empty states

Both empty states are implemented (`widgets/empty/empty_media_view.dart`) and
are the real fallback when a tab has no media. To see them, set either list
in `LocalProfileDataSource` to `const []`.

## Known limitations

- Chats, Contacts and Settings are out of scope. Tapping them shows a short
"This page is not available yet" notice and the profile stays open.
- The header action buttons and the preview menu show a "Not part of this
demo yet" notice, and the top-bar icons only show a ripple, since there is
no navigation target in scope.
- There is no localisation setup. Strings are English, plus the Arabic bio
that comes from the profile data.



## Animation and scrolling notes

[NOTES.md](NOTES.md) explains the key animation and scrolling decisions: why
the header is a `SliverPersistentHeader` rather than a scroll listener, how
rebuilds are kept flat during scrolling, how the snapping works, and the
phase table behind the header morph.

## Screen recording

The demo video (`Demo.mp4`) is on Google Drive, as it is too large for the
repository:

**[Watch the demo on Google Drive](https://drive.google.com/drive/folders/1nskyS4-AG9HWZPV_H0LUXjtmi87i_1fs?usp=sharing)**

It is a capture from a Samsung A55 walking through the same gestures as the
reference video: the resting state, pulling open the cover, snap on release,
the swallow into the app bar, the pinned tabs, and switching to Archived
Posts.