# macOS Custom Cursor Demo

This copy is the only-cursor version: it hides the native macOS pointer while showing the selected custom cursor.

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

## How to use

Open the folder in Xcode, run the app, and press `Enable everywhere`.
When macOS asks for permission, enable the app in **System Settings > Privacy & Security > Accessibility**,
then press the button again. Use `Disable everywhere` to restore the normal cursor.
