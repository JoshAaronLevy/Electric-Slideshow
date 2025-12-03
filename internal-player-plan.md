# Internal Spotify Player Implementation Plan

> Goal: ship a fully embedded Spotify playback experience without requiring the external Spotify app. This plan is split into concrete stages so we can execute incrementally and validate at each step. Every stage lists code touchpoints across the macOS app (`Electric Slideshow`) and the backend (`electric-slideshow-server`).

## Stage 0 – Prerequisites & Research
- **Confirm licensing/compliance**: Spotify Web Playback SDK requires Premium and prohibits certain commercial uses. Document approval or constraints.
- **Select Chromium embedding strategy**: choose between Chromium Embedded Framework (CEF) or a lightweight Electron/Chromium helper. Recommendation: CEF for tighter UI integration. Capture pros/cons, binary size, signing implications in this doc.
- **Environment verification**: build a standalone prototype CEF app that loads `internal_player.html` and confirm Widevine DRM works (device shows up in Spotify Connect).
- **Build pipeline prep**:
  - Update Xcode project to support additional helper targets/binaries (CEF subprocesses).
  - Ensure CI/CD can notarize/sign larger app bundle.

## Stage 1 – Backend Hardening & Telemetry (already started)
1. **Finalize telemetry** (done in previous commit) – ensure `internal_player.html` reports DRM/connection failures.
2. **Add remote config endpoint** in `electric-slideshow-server` to expose feature flags (e.g., enable/disable chromium internal player remotely).
3. **Implement versioned player bundle** support so we can roll out updated HTML/JS without forcing app updates (e.g., `/internal-player?v=2`).

## Stage 2 – Embed Chromium in macOS app
1. **Integrate CEF binaries**
   - Download macOS `Minimal Distribution` of CEF matching Chrome Stable.
   - Add to repo under `ThirdParty/CEF/` and configure Xcode copy phases for helper apps (`cefclient Helper (GPU)`, etc.).
2. **Bridge SwiftUI ↔ CEF**
   - Create `InternalPlayerView` (NSViewRepresentable) that hosts a `CEFView`.
   - Implement message bridge using `CEFMessageRouter` to mirror the previous `WKScriptMessageHandler` API.
3. **Lifecycle management**
   - Preload Chromium during app launch (similar to existing `PlaybackBackendFactory.prewarmInternalBackend`).
   - Handle suspend/resume and graceful shutdown of CEF subprocesses.
4. **Security/sandboxing**
   - Restrict CEF navigation to the internal player URL and SDK assets.
   - Disable local file access, remote debugging, and ensure network requests go only to Spotify/our backend.

## Stage 3 – Rebuild Internal Playback Backend
1. **Refactor `InternalSpotifyPlayer`**
   - Replace WKWebView-specific code with a generic `InternalBrowserHost` protocol (methods: `load(url:)`, `evaluateScript`, `onMessage`). Provide two implementations: `ChromiumBrowserHost` (new) and keep `WebKitBrowserHost` only for development fallback.
2. **Update `SpotifyInternalPlaybackBackend`**
   - Ensure token injection, command execution, and event wiring work via the new browser host.
   - Add fast failure when `widevine_unavailable` event arrives.
3. **Device registration validation**
   - Add diagnostics that fetch `/me/player/devices` until the Chromium-based device appears, log device ID, and expose readiness to UI.
4. **Playback control parity**
   - Verify `play/pause/next/previous/seek` flows through Chromium instance and update unit tests or diagnostic logs accordingly.

## Stage 4 – UX & Settings
1. **Feature toggle UI**
   - Add settings screen allowing user to choose “Internal Player (Beta)” vs “External Spotify App”. Default to internal once stable.
2. **Error messaging improvements**
   - When internal player fails, present actionable guidance (e.g., “Chromium helper crashed – restart app”).
3. **Now Playing surfacing**
   - Update `NowPlayingView` to reflect that playback is local (show device name, connection status).

## Stage 5 – Testing & Stabilization
1. **Automated tests**
   - Build integration test harness that launches the app with Chromium and asserts device appears via Spotify Web API (may require mock tokens or Spotify test account).
2. **Performance profiling**
   - Measure memory/CPU impact of Chromium subprocesses; optimize preloading and teardown.
3. **Crash/recovery handling**
   - Detect Chromium crashes and auto-restart the helper without requiring full app relaunch.

## Stage 6 – Deployment & Rollout
1. **Beta rollout**
   - Ship to internal testers/TestFlight-equivalent with toggles.
   - Collect telemetry (device readiness times, error codes).
2. **Production enablement**
   - Flip remote feature flag to default internal player for all users once stability goals met.
3. **Post-launch monitoring**
   - Dashboard showing internal-player success rate, fallback occurrences, Chromium crash stats.

## Stage 7 – Nice-to-haves / Future Work
- **Audio ducking**: integrate with macOS audio session APIs to lower volume during notifications.
- **Offline mode**: cache playlists locally if Spotify APIs permit.
- **Custom UI overlay**: render minimal playback UI within Chromium instance for debugging.

---

Each stage can be executed and code-reviewed separately. Let me know when you’d like to start with Stage 0 or 1, and I’ll proceed accordingly.
