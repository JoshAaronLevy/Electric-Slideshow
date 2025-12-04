# CEF-Based Internal Player Architecture

## Overview
- We will embed the Chromium Embedded Framework (CEF) inside the macOS app to host the Spotify Web Playback SDK.
- Electric Slideshow remains a single-window SwiftUI app; CEF renders off-screen and streams audio without displaying UI.
- Lifecycle mirrors existing `InternalSpotifyPlayer`: preload on launch, reuse across slideshows.

## Bundle layout
```
Electric Slideshow.app
└─ Contents/
   ├─ Frameworks/
   │  └─ Chromium Embedded Framework.framework
   ├─ Frameworks/
   │  └─ ESChromium Helper.app (GPU/Renderer/Plugin variants)
   └─ Resources/
      └─ cef.pak, locales/*, snapshot_blob.bin, v8_context_snapshot.bin
```
- Helpers follow the same naming/signing approach used by standard CEF samples.
- `ThirdParty/CEF/` in the repo will store the exact binary build + SHA256.

## Process architecture
- **Browser process** (inside host app) – runs CEF, loads `internal_player.html` in a hidden view.
- **Renderer process** – executes JS/Spotify SDK; communicates with browser via IPC.
- **GPU process** – used for audio pipeline even when no graphics surface is visible.
- All subprocesses must inherit the app sandbox profile (hardened runtime) and be codesigned.

## Message bridge
- Use `CEFMessageRouter` to expose a `playerEvent` channel mirroring WKWebView’s `window.webkit.messageHandlers.playerEvent`.
- Swift side implements a new `ChromiumBrowserHost` with:
  - `load(url:)`
  - `evaluateJavaScript(_:completion:)`
  - `setMessageHandler(_:)`
- JS shim will detect if `window.webkit` is absent and instead call `window.ESNativeBridge.postMessage`, which routes through CEF.

## Networking & security
- Restrict navigation to:
  - `https://electric-slideshow-server.onrender.com/internal-player`
  - `https://sdk.scdn.co/spotify-player.js`
- Disable file access from URLs, WebRTC, and remote debugging ports.
- Enforce custom user-agent string identifying Electric Slideshow (helps Spotify support).
- Validate certificates (no custom roots) to avoid MITM exposure.

## Signing & notarization
- Each helper app + the Chromium framework must be codesigned with the main bundle identifier and the hardened runtime enabled.
- Post-build script:
  1. Copy CEF payloads into `DerivedData/.../Build/Products/Release/Electric Slideshow.app`.
  2. Re-sign helper apps using `codesign --force --options runtime --deep`.
  3. Zip app and submit via `notarytool` (expect larger upload ~350 MB).
- Documented in `docs/build/cef-signing.md` (to be written during Stage 2).

## Maintenance strategy
- Track CEF releases via `https://cef-builds.spotifycdn.com` (example URL) and plan quarterly updates.
- Add a script (`scripts/update_cef.sh`) to download + verify new builds.
- Keep the CEF version aligned with Chrome stable to receive security patches quickly.

## Risks
- Increased app size and memory footprint (baseline ~300 MB RAM dedicated to Chromium).
- Potential sandbox or entitlements issues when combining CEF with existing Photo Library access.
- Additional attack surface: ensure auto-update of CEF and monitor CVEs.

_Last updated: 2025-12-03_
