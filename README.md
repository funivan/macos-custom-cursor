# macOS Custom Cursor Demo

Small SwiftUI macOS app that can swap the cursor inside the app window or across macOS.

## Apple Silicon and GPT/Codex

This app is compatible with Apple Silicon Macs (M1, M2, M3, and later). It uses
SwiftUI, AppKit, and CoreGraphics only; there is no Claude/Anthropic dependency
and no model-specific runtime in the app. GPT or Codex can therefore be used to
develop and modify the project without changing the application code.

To build locally on an Apple Silicon Mac:

```sh
swift build -c release
```

To produce an app that runs natively on both Apple Silicon and Intel Macs, build
once for each architecture and combine the executables with `lipo`:

```sh
swift build -c release --arch arm64
swift build -c release --arch x86_64
lipo -create \
  .build/arm64-apple-macosx/release/CustomCursorDemo \
  .build/x86_64-apple-macosx/release/CustomCursorDemo \
  -output CustomCursorDemo
```

The universal build is optional; an M1 Mac should use the native `arm64` build.

## What it does

- Lets you switch between heart, kitty, star, flower, and sparkle cursors
- Shows how to build custom `NSCursor` images in code
- Works inside the app window by calling `NSCursor.set()` while hovering
- Can show the selected cursor globally with the `Enable everywhere` button

## Important note

Global mode uses an Accessibility permission, a mouse event tap, and a transparent overlay.
The app hides the native cursor and displays the selected image above other windows.
Some games may block event taps or behave differently in exclusive fullscreen mode.

## Files

- `CustomCursorDemoApp.swift`
- `ContentView.swift`
- `OnlyCursorVersion/` — a variant that hides the native pointer while showing the selected custom cursor

## How to use

Open the folder in Xcode, run the app, and press `Enable everywhere`.
When macOS asks for permission, enable the app in **System Settings > Privacy & Security > Accessibility**,
then press the button again. Use `Disable everywhere` to restore the normal cursor.
