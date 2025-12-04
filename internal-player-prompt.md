# Context & Problem

I have a macOS Swift/SwiftUI app called **Electric Slideshow** that syncs Apple Photos slideshows with Spotify playlists.

I’ve now built a **separate Electron + React internal player app** called `electric-slideshow-internal-player`. That Electron app:

- Runs the **Spotify Web Playback SDK**.
- Exposes a global JS API like:
  ```ts
  window.INTERNAL_PLAYER = {
    setAccessToken(token: string): void;
    getStatus(): InternalPlayerStatus;
    // plus some basic status UI
  };
  ```

* Supports taking a Spotify access token from the environment via `SPOTIFY_ACCESS_TOKEN=<token>` when launched (Stage 4 in that repo), or via a manual UI / DevTools.

My goal now is to integrate this internal player with the **Swift macOS app** so that:

1. When the user enables “internal player” mode (or some setting), the Swift app:

   * Launches the Electron internal player as a separate **local process**.
   * Injects the latest Spotify OAuth access token via environment variable `SPOTIFY_ACCESS_TOKEN`.
2. The internal player then registers itself as a Spotify Connect device (via the Web Playback SDK) and plays audio internally.
3. When the app quits or the user explicitly disables the internal player, Swift should **shut down** the Electron process cleanly.

I do **not** want to rewrite the Swift app in Electron. The Electron app is a companion process whose only job is: “be the internal Spotify player.”

---

## Tech Stack & Repo Layout

* **Main app (this repo):**

  * macOS app “Electric Slideshow”.
  * Swift + SwiftUI.
  * Already has Spotify auth and API services (e.g. `SpotifyAuthService`, `SpotifyAPIService`, etc.).
  * Currently uses external playback devices; no internal player is running by default.

* **Internal player (separate repo):**

  * Name: `electric-slideshow-internal-player`.
  * Electron + React + TypeScript, built with `electron-vite`.
  * For development:

    * I can run it with `npm run dev` inside that repo.
  * Stage 4 in that repo added support for reading `SPOTIFY_ACCESS_TOKEN` from the environment and calling `INTERNAL_PLAYER.setAccessToken(token)` automatically on startup.

* **Workspace:**

  * In VS Code, I have all of these repos in a single workspace:

    * `Electric-Slideshow` (Swift/macOS)
    * `electric-slideshow-server` (Node backend, deployed to [https://electric-slideshow-server.onrender.com](https://electric-slideshow-server.onrender.com))
    * `electric-slideshow-internal-player` (Electron internal player)

For simplicity, you can assume that the Electron project lives at a sibling path relative to the Swift repo, something like:

```text
../electric-slideshow-internal-player
```

If we need to, we can later move this path into a config or user preference.

---

## Desired Integration Behavior (Swift side)

1. **Internal player manager in Swift**

   I want a dedicated Swift type (e.g. `InternalPlayerManager`) that:

   * Knows how to:

     * Launch the Electron internal player as a `Process`.
     * Pass `SPOTIFY_ACCESS_TOKEN` into that process’s environment.
     * Track whether the player process is running.
     * Shut down the process when no longer needed.

   * Provides a simple, high-level API to the rest of the app, something like:

     ```swift
     protocol InternalPlayerControlling {
         var isRunning: Bool { get }
         func start(withAccessToken token: String) async throws
         func stop() async
     }
     ```

     Or similar—naming and exact API are flexible, but keep it simple and explicit.

   * For now, I don’t need rich IPC back from Electron. Just:

     * ability to launch with the correct token,
     * and ability to stop it.

2. **Connection to existing Spotify auth**

   * We already have code that fetches and refreshes Spotify OAuth tokens (e.g. `SpotifyAuthService.getValidAccessToken()` or similar).
   * I want the internal player to always get a **fresh, valid token** when it is started.
   * For v1, if the token expires, it’s acceptable for me to manually restart the internal player. Automatic re-tokenization can come later.

   So:

   * There should be a clear “integration point” in the Swift app where:

     * We obtain a valid access token from our existing auth flow.
     * We call `internalPlayerManager.start(withAccessToken: token)`.

3. **UI toggle / user control**

   For now, I’d like a simple, non-fancy way for the user to:

   * Enable or disable the internal player from within the app.
   * See whether the internal player appears to be “running” (as far as the Swift process knows).

   This could be:

   * A toggle in a settings/preferences view, or
   * A small section in a sidebar / status area, e.g.:

     * “Internal Player: [Start] / [Stop]”
     * Status label: “Not running” or “Running”.

4. **App lifecycle**

   * When the entire `Electric Slideshow` app quits, we must ensure the Electron internal player process is also terminated.
   * This should be handled in a central, predictable place (e.g., the `App` struct or an app-level coordinator).

---

## Do NOT Write Tests

* **Do NOT** add any unit tests or UI tests as part of this work.
* Focus on:

  * Clean abstractions,
  * Good naming,
  * Logging,
  * And straightforward integration.

Tests can be added later after the flow is validated.

---

## Implementation Strategy & Stages (Swift side)

Please work in staged fashion, similar to what we did for the Electron repo.

### Stage 0 – Swift Integration Plan (doc only)

First, generate a concise plan file, e.g. `INTERNAL_PLAYER_SWIFT_PLAN.md` in this repo, that answers:

1. **Where in the Swift app** we will:

   * Put the `InternalPlayerManager` (e.g. `Services/InternalPlayerManager.swift`).
   * Hook into the app lifecycle to stop the player on quit.
   * Add UI control (which view / feature is the best candidate to host internal player controls).

2. **How we will launch the Electron process**:

   * Use Swift `Process` to start `npm run dev` or a more direct Electron entry, with a configurable command.
   * For now, it’s acceptable to hardcode a dev-only path to the Electron project (e.g. `../electric-slideshow-internal-player`) behind a single constant or configuration struct, with a comment that it should be made configurable later.
   * How we will set the `SPOTIFY_ACCESS_TOKEN` env var for that process.

3. **How we will get a valid Spotify token**:

   * Reference the existing auth service (e.g., `SpotifyAuthService.getValidAccessToken()`).
   * Decide where we call this to start the internal player.

4. **What the user-visible controls will be**:

   * Which view or feature gets a Start/Stop button or toggle.
   * How we bind the UI to `InternalPlayerManager.isRunning`.

For Stage 0: **do not modify any Swift code**, just write the plan file.

---

### Stage 1 – Implement `InternalPlayerManager` (no UI yet)

After the plan is written and I say “Please proceed with Stage 1”:

* Create a new Swift type (class or actor, your choice) e.g. `InternalPlayerManager` in a reasonable location (e.g. `Electric_Slideshow/Services/InternalPlayerManager.swift` or similar).

Responsibilities:

1. **Process management**:

   * Hold a reference to an optional `Process` representing the Electron internal player.

   * Implement:

     ```swift
     var isRunning: Bool { get }

     func start(withAccessToken token: String) async throws
     func stop() async
     ```

   * Starting should:

     * If a process is already running, either:

       * no-op, or
       * stop and restart — document the behavior.
     * Configure a `Process` with:

       * `executableURL` pointing to `/usr/bin/env`
       * `arguments` such that we effectively run:

         ```bash
         SPOTIFY_ACCESS_TOKEN="<token>" npm run dev
         ```

         in the `../electric-slideshow-internal-player` directory.
       * `environment` inherited from the current process, but with `SPOTIFY_ACCESS_TOKEN` added/overridden.
       * `currentDirectoryURL` set to the internal player project directory.
     * Launch the process and track it in a stored property.
     * Log to console on start success/failure.

   * Stopping should:

     * Safely terminate the process if it exists and is still running (e.g. call `terminate()` and/or `interrupt()`).
     * Clear the stored reference.
     * Log to console.

2. **Safety & debugability**:

   * Use logging like:

     ```swift
     print("[InternalPlayerManager] Starting internal player with token: \(token.prefix(8))…")
     print("[InternalPlayerManager] Process launched with PID \(process.processIdentifier)")
     print("[InternalPlayerManager] Stopping internal player")
     ```

     (Never log the full token.)
   * Handle obvious errors (e.g., missing directory) gracefully, with clear error messages.

3. **App lifecycle hook (no UI yet)**:

   * Wire the `InternalPlayerManager` into the app-level structure so that:

     * On app termination, `stop()` is called.
   * This might mean:

     * Injecting an `InternalPlayerManager` into the `@main` `App` struct as a `@StateObject` or environment object, and calling `stop()` in `scenePhase == .background` or similar.
     * Or using an app-level coordinator/singleton—whatever fits the existing architecture best.

Do **not** add any SwiftUI buttons yet in Stage 1; just create the manager and lifecycle hook.

---

### Stage 2 – Wire to Spotify Auth and add simple UI controls

After Stage 1 is complete and I say “Please proceed with Stage 2”:

1. **Integration with existing Spotify auth**:

   * Identify the best place to request a valid Spotify token using the existing auth service.

     * It could be:

       * A settings view where the user clicks “Start Internal Player”.
       * A top-level control in a sidebar.
   * When the user chooses to start the internal player:

     * Call something like:

       ```swift
       let token = try await spotifyAuthService.getValidAccessToken()
       try await internalPlayerManager.start(withAccessToken: token)
       ```
     * If there is an error, show a simple alert or console log, depending on how the app currently handles errors.

2. **UI controls**:

   * Add a small, clear UI fragment (wherever makes sense in the app) that shows:

     * A “Start Internal Player” button (or toggle).
     * A “Stop Internal Player” button, or, if you use a toggle, starting and stopping should be logically wired to the toggle.
     * A simple status label bound to `isRunning`:

       * “Internal Player Status: Running” or “Not Running”.
   * Keep styling minimal; just make it obvious and functional.

3. **Error handling**:

   * If starting fails (e.g., missing Electron project directory), log a clear error and update some simple error string for the UI if appropriate.
   * Prefer not to crash the app; just show that the internal player could not be started.

---

### Stage 3 – Light polish & docs (Swift side only)

If/when we get to Stage 3:

* Add a short comment block or small Markdown section in the repo describing:

  * How to run the internal player in development:

    * “Make sure `../electric-slideshow-internal-player` exists and has `npm install` run at least once.”
    * Then in the app: click “Start Internal Player”.
  * That the Electron side expects `SPOTIFY_ACCESS_TOKEN` and will auto-use it on startup.
* Add any minor refinements to logging or configuration paths as needed.

---

## How to proceed now

1. For your **first response**, please:

   * Create the `INTERNAL_PLAYER_SWIFT_PLAN.md` file for Stage 0.
   * Don’t modify any Swift code yet.
   * Summarize where you intend to place `InternalPlayerManager`, how you’ll hook into app lifecycle, and where you’ll put the UI controls.

2. Once I review that plan, I will say:

   * **“Please proceed with Stage 1.”**
   * At that point, implement Stage 1 exactly as described above.

Remember:

* No tests.
* Prefer clarity and explicitness over clever abstractions.
* Don’t overcomplicate IPC yet; just launching Electron with `SPOTIFY_ACCESS_TOKEN` is enough for v1.