<img src="icon.png" width=150 />

# SensibleSideButtons

macOS mostly ignores the M4/M5 mouse buttons, commonly used for navigation. Third-party apps can bind them to ⌘+[ and ⌘+], but this only works in a small number of apps and feels janky. With this tool, your side buttons will simulate 3-finger swipes, allowing you to navigate almost any window with a history. As seen in the Logitech MX Master!

Extensive information on this tweak can be found here: https://sensible-side-buttons.archagon.net

## Features

- Translates mouse button 4/5 into system-wide 3-finger swipe gestures
- Menu bar icon with enable/disable, swap buttons, trigger-on-down options
- Global hotkey **⌘⇧B** to toggle menu bar icon visibility
- macOS version check — warns if running on an untested release
- Graceful failure handling — if gesture synthesis fails, the button press passes through instead of being swallowed
- Periodic Accessibility (TCC) permission monitoring
- Hardened runtime enabled

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧B | Toggle menu bar icon visibility |
| ⌘E | Toggle enabled (when menu is open) |
| ⌘Q | Quit (when menu is open) |

## Building

Requires Xcode (full install, not just Command Line Tools).

```bash
./build.sh          # Release universal binary (arm64 + x86_64)
./build.sh Debug    # Debug build
```

The built app is at `build/Release/SensibleSideButtons.app`.

### Swift Target

The `SideButtonFixer/Swift/` directory contains a Swift + SwiftUI rewrite. To build it, create a new Xcode target with:
- Sources: `SideButtonFixer/Swift/*.swift` + `External/TouchEvents.c`
- Bridging Header: `SideButtonFixer/Swift/BridgingHeader.h`
- Deployment Target: macOS 10.13+
- Hardened Runtime: enabled

## Installation

1. Build or download the app
2. Move `SensibleSideButtons.app` to `/Applications/`
3. Launch it — grant Accessibility permission when prompted
4. (Optional) Add to Login Items for auto-start:
   - System Settings → General → Login Items → add the app

## License

GPLv2 — see [LICENSE](LICENSE).
