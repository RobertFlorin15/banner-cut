# BannerCut

BannerCut is a native Flutter app that helps you turn discarded event banners into tote bags and sleeves. It plans cuts around damaged areas so you can recover more usable material. The project supports Android, iOS, and Linux.

## Run locally

Use Flutter 3.44.8 or a Flutter release that meets the Dart 3.12.2 SDK constraint in `pubspec.yaml`. Run these commands from the project root.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

- **Linux** — Run `flutter run -d linux` from a terminal in your desktop session.
- **Android** — Start an emulator or connect a phone with USB debugging enabled. To build an APK for testing, run `flutter build apk --debug`.
- **iOS** — Use macOS with Xcode and an iOS device or simulator running iOS 14 or later.

## Plan a cut

1. Explore the preloaded example or select **New banner** from the project menu. Enter the banner's width and height in centimeters.
2. Optionally add a straight-on photo cropped to the banner's edges. In **Edit**, drag rectangles over damaged areas. You can remove individual areas as needed.
3. Choose a **Tote bag** or **Sleeve** pattern. Set the seam allowance per side and the maximum number of complete sets.
4. In **Manual**, tap where the top-left corner of the next piece should go. You can rotate the piece before placing it or undo the last placement.
5. Select **Optimize plan**. Compare it with the **Baseline** layout without rotations and with your manual layout once it has a complete set. Tap a piece to see its dimensions and its position relative to the banner's top-left corner. Open **Cut list** to copy all dimensions and coordinates.

BannerCut starts in English. Choose **Română** from the project menu to switch languages during the session. Photos and plans are processed locally and kept in memory for the current session. Changing the dimensions, pattern, seam allowance, set limit, or damaged areas clears the existing layouts.

## Optimization and impact

The planner splits the available space into rectangles around damaged areas and placed pieces. It tries several piece orders and placement rules, with optional 90° rotations, and keeps the best layout it finds by complete set count. This is a heuristic.

**Material usage** is the area of the pieces in complete sets, including seam allowances, divided by the usable banner area. Overlapping damaged areas are counted once. To measure physical waste, weigh the offcuts from comparable banners cut with the same pattern and seam allowance.

## Checks

```sh
flutter analyze
flutter test
```

Tests cover damaged-area overlaps, piece rotation, seam allowances, incomplete sets, and the editing, optimization, and language-switching flows.
