# Edit.or.lynx v2.0.1 Release (v2.0.1)
*Published: 2026-10-29 10:53:39*

Maintenance and continuous refinement release (2026-10-29 10:53:39).

### Highlights in this Release:
- **Pure Notchy G2 Squircle Geometry**: Full G2 continuous curvature (R * 1.28 extent, 0.44R and 0.82R control points) and outward top ear flairs.
- **Liquid Glass Materials**: Support for both Dark Mode (.liquidGlass, .matteDark, .trueBlack) and Light Mode (.liquidLight, .matteLight) with dynamic specular highlights and razor rim strokes.
- **Card-Based Settings System**: High-density grouped cards with custom toggles, sliders, menus, and dedicated Downloader pane.
- **Continuous 120 BPM Motion Engine**: 1440x1440 analytical spring-driven UI morph across 12 distinct UI states with 4x subframe motion blur at 60fps.
- **Performance Optimization**: <1% idle CPU utilization through paused timers and compositor-driven rendering.

---
# Edit.or.lynx v2.0.0 Release (v2.0.0)
*Published: 2026-10-29 10:47:53*

Complete Notchy.app architecture parity, Apple G2 squircle geometry, liquid glass materials in Dark and Light modes, and closed-form 120 BPM motion engine.

### Highlights in this Release:
- **Pure Notchy G2 Squircle Geometry**: Full G2 continuous curvature (R * 1.28 extent, 0.44R and 0.82R control points) and outward top ear flairs.
- **Liquid Glass Materials**: Support for both Dark Mode (.liquidGlass, .matteDark, .trueBlack) and Light Mode (.liquidLight, .matteLight) with dynamic specular highlights and razor rim strokes.
- **Card-Based Settings System**: High-density grouped cards with custom toggles, sliders, menus, and dedicated Downloader pane.
- **Continuous 120 BPM Motion Engine**: 1440x1440 analytical spring-driven UI morph across 12 distinct UI states with 4x subframe motion blur at 60fps.
- **Performance Optimization**: <1% idle CPU utilization through paused timers and compositor-driven rendering.

---
# Edit.or.lynx Release Log

## Version 2.0.0 — Notchy Architecture & Continuous Motion Engine

**Release Date:** October 29, 2026  
**Bundle Identifier:** `com.editor.lynx`  
**Author:** Made by edit.or.siva (Instagram: `@edit.or.siva`)

---

### Highlights & Key Improvements

#### 1. Complete Notch Architecture (Reverse-Engineered from Notchy.app)
* **G2 Continuous Squircle (`TopAttachedNotchShape.swift`)**:
  - Implemented Apple's cubic Bézier continuous curvature continuity ($R \times 1.28$ extent, $0.44R$ and $0.82R$ control points).
  - Outward top ear flairs that blend seamlessly into the display's top bezel with zero visible seams or kinks.
* **Hardware-Aligned Window Geometry (`NotchGeometry.swift`)**:
  - Exact hardware notch detection via `NSScreen.safeAreaInsets.top`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea`.
  - Subpixel Retina scale factor rounding (`(val * scale).rounded() / scale`) to prevent blurring and fractional pixel gaps.
* **AppKit Window Clamping Override (`IslandWindow.swift`)**:
  - Overrode `NSWindow.constrainFrameRect(_:to:)` to prevent AppKit from forcing non-activating borderless panels down below the menu bar.
* **Multi-Mode Liquid Glass Materials (`NotchyGlassMaterial.swift`)**:
  - **Liquid Glass (Dark)**: Translucent native HUD glass with specular mono inner highlight and razor rim stroke.
  - **Liquid Glass (Light)**: Translucent frosted crystal glass with dark hairline rim and light-adapted highlight.
  - **Matte Dark / Matte Light**: Solid high-contrast graphite and paper white finishes.
  - **True Black**: OLED/mini-LED pitch black matching the physical notch cutout.
* **Unified Settings System (`SettingsView.swift`, `SettingsComponents.swift`)**:
  - Authentic card-based sidebar navigation matching Notchy.app (`General`, `Appearance`, `Modules`, `Downloads`, `AI`, `Extensions`, `Advanced`, `About`).
  - Modular components: `SettingsGroup`, `SWToggleRow`, `SWDivider`, `SWSliderRow`, `SWMenuRow`, `SWButtonRow`, `SWInfoRow`.
  - Dedicated `DownloaderSettingsView` giving complete control over transfer connections (up to 32), concurrent slots, destination folders, Google Drive auto-zipping, and aria2c torrents.
  - Dedicated `AISettingsView` backed by macOS Keychain security.
  - Dedicated `AboutSettingsView` with personal branding (*"Made by edit.or.siva · Instagram @edit.or.siva"*).

#### 2. Performance Optimization & Idle CPU Reduction
* Fixed idle CPU utilization bug: dropped idle CPU from **~52% down to <1%**.
* Paused idle 30 FPS `TimelineView` in `PuffNotchView` when not hovering.
* Replaced 20 Hz procedural timers in `NotchMascotView` with compositor-driven SwiftUI animations.
* Removed aggressive 2-second background permission polling (`checkBluetooth`, `checkLocation`), moving to event-driven checks on appear and app activation.

#### 3. Continuous Motion Engine (`MotionEngine/`)
* **12-State Beat-Grid Motion Loop**:
  - `Button` → `Loader` → `Check` → `Dynamic Island` → `Music Player` → `Scrub Bar` → `Volume Slider (Rubber-band stretch past max)` → `Toggle Switch` → `Liquid Segmented Tabs` → `Data Chart + Tooltip` → `⌘K Command Palette` → `Toast` → `Loop back to Button`.
* **Analytical Closed-Form Springs**:
  - Zero CSS transitions, zero browser timers, memoryless `seek(t)` evaluation.
  - Superposition of damped harmonic step responses: $s(t) = 1 - e^{-\zeta \omega_n t} (\cos \omega_d t + \dots)$.
* **Liquid Dual-Spring Dynamics**:
  - Leading and trailing edges ride independent differential springs for fluid stretching and organic snapping.
* **Direct Manipulation Drags**:
  - Interactive audio scrubber and volume slider with Hooke's elastic resistance past 100% max.
* **4x Subframe Blur at 60 FPS**:
  - Rendered at 240 fps and blended with ffmpeg `tmix` filter at $1440 \times 1440$ resolution.
  - Synchronized 120 BPM minimal electronic soundtrack with UI transient clicks (`track_120bpm.wav`).
  - Full renders for both **Dark Mode** (`motion_dark_60fps.mp4`) and **Light Mode** (`motion_light_60fps.mp4`).

#### 4. Feature Preservation
* 100% retention of all Pounce downloader pipelines, torrent services, Google Drive batch zipping, AI provider keychains, Shelf, Clipboard, Now Playing, and Mascot system.
