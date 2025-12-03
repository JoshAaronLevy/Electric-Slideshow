# Internal Spotify Player Implementation Plan

> Goal: ship a fully embedded Spotify playback experience without requiring the external Spotify app. This plan is split into concrete stages so we can execute incrementally and validate at each step. Every stage lists code touchpoints across the macOS app (`Electric Slideshow`) and the backend (`electric-slideshow-server`).

## Stage 0 – Prerequisites & Research (CEF-focused)

### 0.1  Spotify licensing & compliance audit
- Confirm the Spotify account used in development has Premium (Web Playback SDK hard requirement) and document that MVP will require Premium end-users.
- Review and log the Web Playback SDK Terms + Developer Policy items that impact us:
   - No caching/downloading of audio; playback must be streaming only.
   - Internal player cannot be used in commercial hardware integrations without additional approval.
   - App must show standard Spotify branding and attribution if player UI becomes visible (capture what “non-visual” mode requires).
- Draft a short compliance matrix in `docs/spotify-compliance.md` (owner: Josh) covering current status, gaps, and any legal follow-ups.
- Exit criteria: compliance doc signed off by product + legal stakeholders (email acknowledgement is fine for MVP).

### 0.2  Chromium strategy decision (CEF)
- We will embed **Chromium Embedded Framework (CEF)** directly to keep everything inside the main window.
- Document pros/cons (for future reference) in the plan:
   - ✅ Tight SwiftUI integration, no extra helper app UI, consistent lifecycle.
   - ✅ Better control over navigation sandboxing.
   - ❌ Larger binary (~250 MB uncompressed) and extra helper processes to codesign.
   - ❌ Manual updates when Chrome releases security patches.
- List required frameworks/binaries: `Chromium Embedded Framework.framework`, helper executables (`cefclient Helper`, `cefclient Helper (GPU)`, `cefclient Helper (Renderer)`), locales, resources, Swift bridging headers.
- Capture signing/notarization implications:
   - Each helper must be codesigned with the same Team ID and included in the notarization submission.
   - Xcode project needs additional Run Script phase to re-sign helpers after copying CEF payload.
- Exit criteria: architecture note (1–2 pages) stored in `docs/internal-player/cef-architecture.md` describing the above and approved by engineering lead.

### 0.3  Standalone CEF prototype
- Build a minimal macOS app (outside main repo or inside `Prototypes/CEFPlayer/`) that:
   1. Loads CEF minimal distribution (matching Chrome stable version).
   2. Opens a single window pointing to `https://electric-slideshow-server.onrender.com/internal-player`.
   3. Exposes a console/log so we can see `playerEvent` messages.
- Verification steps:
   - Inject a valid Spotify access token manually (temporary UI button) and ensure `player.connect()` succeeds (device shows in `spotify.com/pair` or the mobile app).
   - Capture logs/screenshots proving Widevine works (device ID, `connectResult: connected`).
   - Measure cold-start time and memory footprint of the prototype for baseline metrics.
- Exit criteria: prototype repo committed, README explains manual steps, and we have proof that DRM works inside CEF.

### 0.4  Build pipeline & project preparation
- **Repository layout**: create `ThirdParty/CEF/README.md` documenting download source, version, and hash for the CEF bundle. Add Git LFS or alternate storage if the bundle is too large for Git.
- **Xcode project changes** (design only for Stage 0):
   - Plan new targets for CEF helpers or adopt the official CEF Xcode template.
   - Identify where to place CEF resources within the `.app` bundle (`Contents/Frameworks/Chromium Embedded Framework.framework`).
- **CI/CD impact**:
   - Update build agents to install `xcode-select --switch` version that supports hardened runtime signing of nested frameworks.
   - Ensure notarization pipeline can handle >1 GB artifacts (CEF inflates zipped app size).
- Produce a checklist (`docs/internal-player/stage0-checklist.md`) enumerating all tasks above with owners/dates so Stage 1 can consume it.
- Exit criteria: checklist complete, stakeholders agree that requirements are satisfied, and Stage 1 tickets can be created.

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
