# RedPill 2026 (Metal)

A 3D "Matrix" digital rain screensaver for macOS, rendered with Metal.


[![RedPill-2026-Metal Demo Video](https://img.youtube.com/vi/dM-aSSvJqhg/maxresdefault.jpg)](https://www.youtube.com/watch?v=dM-aSSvJqhg)


![Matrix Digital Rain](https://img.shields.io/badge/Matrix-Digital%20Rain-green?style=for-the-badge)
![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=for-the-badge)
![Architecture](https://img.shields.io/badge/Architecture-arm64%20%7C%20x86__64-orange?style=for-the-badge)



This is the Metal port of [AkimoA/RedPill-2025](https://github.com/AkimoA/RedPill-2025), which is a fork of [Jason Short's RedPill2](https://github.com/jasonshortphd/RedPill2). The OpenGL renderer was replaced by Metal. Animation logic, preferences and look are unchanged.

## Requirements

- macOS 13.5 or later (project deployment target)
- Apple Silicon or Intel Mac with Metal support
- Xcode, to build from source

## What changed from the OpenGL version

| OpenGL | Metal |
|--------|-------|
| `NSOpenGLView` (`MatrixOpenGLView`) | `CAMetalLayer` view (`MatrixMetalView`) |
| `glVertexPointer` / `glColorPointer` / `glTexCoordPointer` + `glDrawArrays(GL_QUADS)` | One shared vertex buffer per frame, one draw call (`MatrixStrip.writeQuads`) |
| `glTexImage2D` from `Glyphs.png` | `MTLTexture` (`rgba8Unorm`) |
| `GLKMatrix4MakePerspective` | Perspective matrix in `MatrixRenderer` (45 degree FOV, near 40, far 300) |
| `glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)` | Blend state in the render pipeline |
| `GL_MODULATE` texture env | Texture times vertex color in the fragment shader |
| `GL_FOG` (linear, black) | Linear fog in the fragment shader, off when fog setting is 0 |
| OpenGL.framework + bridging header | Metal.framework, no bridging header |

Behavior kept as is:

- Strip spawning, cursor state machine, color cycling and glow
- Cursor motion trails
- All preferences (strips, velocity, depth, cycling, falling, cursor, fog, top start, main screen only)
- Rendering at 30 FPS (`animationTimeInterval`)

Differences:

- Renders at native Retina resolution
- `MatrixView` draws from `animateOneFrame` instead of `draw(_:)`

## Installation

1. Download `RedPill.saver` from [Releases](https://github.com/AkimoA/redpill-2026-metal/releases) or build it (see below)
2. Double-click `RedPill.saver` to install, or copy it to:

```
~/Library/Screen Savers/          # current user
/Library/Screen Savers/           # all users
```

3. Open System Settings > Desktop & Screen Saver
4. Select **Red Pill**

### "Can't be opened" warning

The build is unsigned. To allow it:

1. System Settings > Privacy & Security
2. Scroll to Security and click **Allow Anyway** next to RedPill.saver
3. Select **Red Pill** again in Desktop & Screen Saver and click **Open Anyway**

## Building from source

```
git clone https://github.com/AkimoA/redpill-2026-metal.git
cd redpill-2026-metal
open RedPill.xcodeproj
```

Or from the terminal:

```
xcodebuild -project RedPill.xcodeproj -target RedPill -configuration Release build
cp -R build/Release/RedPill.saver ~/Library/Screen\ Savers/
```

If Xcode 26 reports a missing Metal Toolchain, run once:

```
xcodebuild -downloadComponent MetalToolchain
```

## Project layout

| File | Purpose |
|------|---------|
| `MatrixView.swift` | `ScreenSaverView` entry point, preferences, strip spawning, frame loop |
| `MatrixStrip.swift` | One strip of glyphs: animation state and vertex output |
| `MatrixStripParams.swift` | Animation parameters |
| `MatrixRenderer.swift` | Metal device state, pipeline, vertex buffers, projection |
| `MatrixShaders.metal` | Vertex and fragment shaders (texture modulate, linear fog) |
| `MatrixMetalView.swift` | `CAMetalLayer` hosting view |
| `MatrixTexture.swift` | Loads `Glyphs.png` into an `MTLTexture` |
| `MatrixPrefsWindow.swift` | Preferences sheet (`Matrix.nib`) |
| `MatrixMacros.swift` | Shared constants |
| `MatrixUtils.swift` | Error logging |

## Troubleshooting

### Black screen

- Check Privacy & Security for the blocked-screensaver prompt
- Check Console.app for lines starting with `RedPill Error`
- Errors such as "Failed to load Metal shader library" mean `MatrixShaders.metal` was not compiled into the bundle; confirm it is in the target's Compile Sources

### legacyScreenSaver process stays running

`MatrixView` handles `com.apple.screensaver.willstop` with a version-specific exit:

- macOS 14 and later: exit after a 2 second delay
- Older macOS: `stopAnimation()` then `exit(0)`

## License and credits

Free software under the GNU General Public License v3.0 or later. See `LICENSE.html`.

- 2002, 2003 mathew (meta@pobox.com) - original creator
- 2016 px3 (rr@rdsroot.net) - first modernization
- Jason Short - macOS 10.15 compatibility ([RedPill2](https://github.com/jasonshortphd/RedPill2))
- 2025 AkimoA - macOS 26 compatibility and legacyScreenSaver workaround from the Aerial project ([RedPill-2025](https://github.com/AkimoA/RedPill-2025))
- 2025 AkimoA & Claude - macOS 27 compatibility Metal port of the renderer

## Links

- This repo: https://github.com/AkimoA/redpill-2026-metal
- OpenGL version: https://github.com/AkimoA/RedPill-2025
- Previous fork: https://github.com/jasonshortphd/RedPill2
- Issues: https://github.com/AkimoA/redpill-2026-metal/issues
