### Context & Problem

This project is a macOS SwiftUI app called **Electric Slideshow**. It has an **internal Spotify player** implemented as an Electron app (`electric-slideshow-spotify-player`) that uses the Spotify Web Playback SDK and appears as a Spotify Connect device (e.g. “Electric Slideshow Internal Player”).

Architecture:

* SwiftUI macOS app = main product users interact with.
* Electron app = internal/headless player.
* Node/Express backend = Spotify OAuth + proxy for Web API calls.

**Important behavioral requirement:**

* In **both dev and prod**, when the user launches **Electric Slideshow.app**, the internal player should be started automatically (once authenticated) and kept running in the background.
* Users should never have to manually launch the Electron app. They should just run Electric Slideshow and it “just works”.

Current situation (high level):

* Dev: `InternalPlayerManager` can start Electron via `npm run dev` and poll for the internal Spotify device.
* Prod: We want to ship a **single macOS app** that **embeds** the packaged Electron app as a helper and launches it as a child process.
* Swift’s internal backend (`SpotifyInternalPlaybackBackend`) still needs to:

  * Start the internal player process (via `InternalPlayerManager`),
  * Poll `/devices` until the internal device appears,
  * Then target that device ID for playback.

We now want to:

1. Solidify the **InternalPlayerManager** abstraction so it handles dev vs prod consistently.
2. Make sure the internal player is **auto-started on app launch** (once auth is ready).
3. Add minimal but clear logging around process lifecycle.

### Constraints

* **Do NOT write tests.**
  No new test files, no changes to any test targets.
* Keep changes localized to the Swift/macOS side (no changes to the Electron repo).
* Assume the Electron app will be packaged as `ElectricSlideshowInternalPlayer.app` and embedded in the main app bundle under `Contents/Resources`.

---

### Files to Focus On

Please locate and work on these (use the actual paths/names you find):

* `Services/InternalPlayerManager.swift` (or similar).
* `Services/SpotifyInternalPlaybackBackend.swift`.
* `Services/PlaybackBackendFactory.swift` (if needed for wiring / prewarm).
* `Views/AppShellView.swift` (or whatever top-level view / app entry point you used to prewarm the internal backend).

If the exact filenames differ slightly, use the closest equivalents.

---

### Tasks

#### 1. Make InternalPlayerManager robust for dev + prod

**Goal:** `InternalPlayerManager` should be the single place that knows *how* to start and stop the internal Electron player, with different behavior in Debug vs Release builds.

Implement / refactor `InternalPlayerManager` to:

* Track the child `Process` and avoid spawning duplicates.

* Provide clear public API, something like:

  ```swift
  final class InternalPlayerManager {
      static let shared = InternalPlayerManager()

      func startInternalPlayer(accessToken: String, backendBaseURL: URL?) throws
      func ensureInternalPlayerRunning(accessToken: String, backendBaseURL: URL?) throws
      func stopInternalPlayer()
      var isRunning: Bool { get }
  }
  ```

* **Dev behavior (`#if DEBUG`)**:

  * Launch using `npm run dev` in the internal player repo directory, just as you already do.
  * Inject environment variables:

    * `SPOTIFY_ACCESS_TOKEN`
    * Any backend URL you need (e.g. `ELECTRIC_BACKEND_BASE_URL`).

* **Prod behavior (`#else`)**:

  * Resolve the embedded helper app’s executable via the bundle, something like:

    ```swift
    guard let helperURL = Bundle.main
        .url(forResource: "ElectricSlideshowInternalPlayer", withExtension: "app")
        ?.appendingPathComponent("Contents/MacOS/ElectricSlideshowInternalPlayer")
    else {
        throw InternalPlayerError.helperNotFound
    }
    ```

  * Launch a `Process` with `executableURL = helperURL`.

  * Inject the same env vars (`SPOTIFY_ACCESS_TOKEN`, backend URL, etc.).

* Handle process lifecycle:

  * `isRunning` should reflect whether the `Process` is alive.
  * `stopInternalPlayer()` should terminate and nil out the process.
  * If the process exits unexpectedly, we should be able to start it again on next `ensureInternalPlayerRunning`.

Add lightweight logging inside `InternalPlayerManager`:

* When starting (dev vs prod, executable path, whether env vars are set).
* When detecting already running (skip re-launch).
* When stopping / process exits unexpectedly.

Keep logs concise and prefixed, e.g. `[InternalPlayerManager] …`.

> **Note:** You can assume the Electron `.app` is correctly embedded by Xcode via a Copy Files build phase; just use `Bundle.main` to locate it as shown.

---

#### 2. Wire InternalPlayerManager into SpotifyInternalPlaybackBackend.initialize()

**Goal:** When the internal backend initializes, it should **ensure** the internal player process is running *before* we poll for the device.

In `SpotifyInternalPlaybackBackend` (or equivalent):

* In `initialize()` (or the method that sets up the internal backend):

  1. Obtain the current Spotify access token (and backend base URL) via your existing auth/services layer (`SpotifyAuthService`, `SpotifyAPIService`, etc.).
  2. Call `InternalPlayerManager.shared.ensureInternalPlayerRunning(accessToken: …, backendBaseURL: …)`.
  3. After the process is started (or confirmed running), perform your existing device polling loop:

     * Call the backend `/devices` endpoint periodically.
     * Look for the internal player device name (e.g. “Electric Slideshow Internal Player”).
     * When found, store `deviceId` and set `isReady = true`.

* Add minimal logging around init:

  * When `initialize()` starts, log backend mode and that we’re booting the internal player.
  * When we detect the internal device via `/devices`, log the device ID and mark ready.

Make sure:

* Initialization remains **idempotent**:

  * Calling `initialize()` multiple times should not spawn multiple Electron processes.
  * `InternalPlayerManager` should guard against that.

---

#### 3. Auto-start the internal player on app launch (when authenticated)

**Goal:** In **both dev and prod**, opening Electric Slideshow should automatically start + prewarm the internal player once the user is authenticated, so when they hit “Play Slideshow,” the internal device is already available.

In your top-level UI / app shell (e.g., `AppShellView.swift` or equivalent):

* Identify where you already “prewarm” the internal backend (the earlier report suggested this exists).

* Make sure the flow is:

  1. When the user is authenticated (or a valid token is available):

     * Instantiate the internal backend via `PlaybackBackendFactory` (defaultMode should be `.internalWebPlayer`).
     * Call something like `internalBackend.initialize()` (or a dedicated `prewarmInternalBackend()` function).
  2. This should, under the hood:

     * Use `InternalPlayerManager` to start the process,
     * Poll for the internal device,
     * Mark the backend as ready.

* Ensure this happens **once per app session**, not on every view re-render:

  * E.g., store a flag `hasPrewarmedInternalBackend` in the view model or app state.
  * Or use `onAppear` + `Task` with some simple guard to avoid repeated initialization.

Add a tiny bit of logging:

* On app launch / shell appear: `[AppShell] Prewarming internal playback backend…`.
* On success: `[AppShell] Internal playback backend prewarmed successfully.`

This is mostly for our debugging sanity.

---

#### 4. Document the embedding assumption (lightweight)

In the repo, add a short Markdown file (e.g. `docs/internal-player-embedding.md`) summarizing:

* That `ElectricSlideshowInternalPlayer.app` must be built by the Electron project and added to the main app target.
* That it is embedded via a Copy Files phase to `Contents/Resources`.
* That `InternalPlayerManager` expects to find it via:

  ```swift
  Bundle.main.url(forResource: "ElectricSlideshowInternalPlayer", withExtension: "app")
  ```

This is just to keep future-you sane; keep it short and to the point.

---

### Style & Safety

* **No tests**. Please don’t touch any test targets.
* Don’t introduce any heavy new abstractions—just strengthen `InternalPlayerManager` + backend init wiring.
* Keep logging minimal but clear (no token values, no secrets).
* Be careful not to break the existing dev workflow:

  * `npm run dev` should still be used in Debug builds so I can iterate on Electron.

---

### Acceptance Criteria

When you’re done, the code should satisfy:

1. **Single-app experience**:

   * In Debug:

     * Launching Electric Slideshow starts the Electron internal player via `npm run dev` automatically (once authenticated), without me manually running it.
   * In Release:

     * Launching Electric Slideshow starts the embedded `ElectricSlideshowInternalPlayer.app` automatically (once authenticated).

2. **Stable internal backend initialization**:

   * `SpotifyInternalPlaybackBackend.initialize()`:

     * Starts (or reuses) the internal player process via `InternalPlayerManager`.
     * Polls for the internal device.
     * Only marks `isReady = true` once the device is found.

3. **No duplicate processes**:

   * `InternalPlayerManager` should not spawn multiple Electron processes for the same app session.

4. **Clear, minimal logs**:

   * Logs clearly indicate:

     * When the internal player process is launched (dev vs prod),
     * When it’s already running and reused,
     * When the internal device is discovered.

Please show the updated Swift code for:

* `InternalPlayerManager` (full file),
* The relevant parts of `SpotifyInternalPlaybackBackend`,
* The part of `AppShellView` (or equivalent) where the prewarm/init logic lives,
* And the brief `docs/internal-player-embedding.md` you add.