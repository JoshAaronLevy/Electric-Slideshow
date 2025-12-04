# Internal Player Swift Integration Plan

## 1. Placement & Lifecycle
- **Manager Location:** Create `InternalPlayerManager` under `Electric Slideshow/Services/InternalPlayer/InternalPlayerManager.swift` (new subfolder keeps process / IPC code isolated from network + auth services).
- **Lifecycle Ownership:** Instantiate `InternalPlayerManager` as a shared `@StateObject` inside `Electric_SlideshowApp` so it flows through the SwiftUI environment. Expose it via `.environmentObject` for any view needing controls.
- **App Quit Handling:** In `Electric_SlideshowApp`, observe `scenePhase` (or use `NSApplicationDelegateAdaptor` if needed) and call `await internalPlayerManager.stop()` when the phase transitions to `.background` or when `applicationWillTerminate` fires. This ensures the Electron companion process is terminated whenever the macOS app quits.
- **Playback Prefetch:** Leave existing `prewarmInternalPlayerIfNeeded()` logic untouched for now; once the manager exists, that helper can optionally trigger a silent start/stop using the same manager APIs.

## 2. Launching the Electron Process
- **Executable Strategy:** Use `Process` with `executableURL = URL(fileURLWithPath: "/usr/bin/env")` and arguments `["npm", "run", "dev"]` so the macOS app leverages the developer's PATH.
- **Working Directory:** Set `currentDirectoryURL` to a constant `internalPlayerProjectURL`, initially pointing to `../electric-slideshow-internal-player` relative to the Swift repo root. Document that this is dev-only and should be made configurable later (e.g., via preferences or plist).
- **Environment Injection:** Start from `ProcessInfo.processInfo.environment`, override `SPOTIFY_ACCESS_TOKEN` with the fresh token, and optionally set `ELECTRIC_SLIDESHOW_MODE=internal-player` for future debugging.
- **Logging & Errors:** Log short-token previews (`token.prefix(8)`) and PID info on start; capture `launch()` errors (missing directory, npm not installed) and expose them via thrown `InternalPlayerError` values so the UI can surface failures without crashing.
- **Process Tracking:** Store the running `Process` plus a DispatchSource (if needed) to observe termination. Stopping should send `terminate()` followed by `waitUntilExit()` on a background task, then nil out references.

## 3. Obtaining a Valid Spotify Token
- **Auth Hook:** Reuse `SpotifyAuthService.shared` (already injected into `AppShellView` and other views). It exposes async token refresh helpers such as `getValidAccessToken()`.
- **Start Flow:** When the user taps "Start Internal Player", the view model (or view) will:
  1. Await `spotifyAuthService.getValidAccessToken()`.
  2. Pass the token into `internalPlayerManager.start(withAccessToken:)`.
- **Manual Restart:** Document that expiring tokens currently require the user to stop/start the internal player; automatic refresh will be a later enhancement.

## 4. User-Facing Controls
- **UI Surface:** Extend `SettingsDashboardView` with a new "Internal Player" tile that opens a lightweight panel/section for controls (fits naturally with other device-related settings).
- **Control Layout:** Inside the settings sheet/panel, show:
  - Status text bound to `internalPlayerManager.isRunning` (via `@EnvironmentObject`).
  - Primary buttons: `Start Internal Player` (triggers token fetch + start) and `Stop Internal Player` (calls `stop`). Disable/enable buttons based on running state.
  - Simple error text if `start` throws (e.g., missing repo path).
- **Future Enhancements:** Later stages can upgrade this to a toggle or integrate directly into the sidebar, but Stage 2 will keep it minimal within Settings.

---

### Stage Sequencing Notes
- **Stage 1:** Implement `InternalPlayerManager`, add lifecycle hook in `Electric_SlideshowApp`, but keep UI untouched.
- **Stage 2:** Wire Settings UI + Spotify auth call path to the manager.
- **Stage 3:** Document dev setup (npm install, repo path), refine logging, and optionally expose configurability for the internal player path.
