## Context & Problem

This repo is the macOS Swift/SwiftUI app **Electric Slideshow**. It already has:

- A Spotify auth flow and services (e.g. `SpotifyAuthService.getValidAccessToken()` or similar).
- An **internal player integration** using a separate Electron app:
  - A type like `InternalPlayerManager` (or similarly named) that launches the Electron internal player as a child `Process` and injects `SPOTIFY_ACCESS_TOKEN` into the environment.
  - Some app-level lifecycle wiring so that the Electron process is stopped when the app quits.
  - Potentially a UI hook (button/toggle) to start/stop the internal player.

Separately, there is a **Electron + React internal player repo** (`electric-slideshow-internal-player`) that:

- Runs the Spotify Web Playback SDK.
- Supports `SPOTIFY_ACCESS_TOKEN` via `process.env` on startup.
- Registers a Connect device like “Electric Slideshow Internal Player”.

I’ve already gone through staged work in both repos; now I want you to:

1. **Verify that the Swift-side wiring is correct** (launch mode, paths, process env).
2. **Ensure there’s a clean, obvious way to manually start/stop the internal player from the UI for testing.**
3. **Generate a Markdown testing checklist** describing how I should exercise this locally end-to-end.

I am *not* asking for new architecture. I want a sanity pass and a simple test harness, not a refactor.

---

## Do NOT Write Tests

- Do **not** add unit tests or UI tests.
- Focus on:
  - Code review-style validation.
  - Minimal, explicit fixes or glue code.
  - A very clear, human-friendly testing checklist.

---

## Tasks

### Task 1 – Inspect & sanity-check the existing integration

1. Find the internal player components:
   - The internal-player manager type (`InternalPlayerManager`, `InternalPlayerService`, or similar).
   - Any enum or struct that represents the launch mode (dev vs bundled).
   - Where the `Process` is created and launched for the Electron app.
   - Any app-level lifecycle integration (e.g., in the `@main` `App` struct or an app coordinator).

2. Check for these things explicitly and **fix them if needed** (with minimal changes):

   - **Dev path correctness pattern**  
     There should be:
     - A single, clearly named **dev-only constant** for the local Electron repo path:
       ```swift
       static let defaultDevRepoPath = "/CHANGE/ME/absolute/path/to/electric-slideshow-internal-player"
       ```
       or similar, with a `// TODO` comment that I will edit.
     - No hard-coded paths scattered around in multiple places.

   - **Process environment wiring**  
     In dev mode, the `Process` should:
     - Use `currentDirectoryURL` pointing at the Electron repo root.
     - Set `SPOTIFY_ACCESS_TOKEN` in the environment (either via `process.environment` or `"SPOTIFY_ACCESS_TOKEN=..."` in the arguments).
     - Run a clear command like `npm run dev`.

     Prefer a single, readable implementation, for example:

     ```swift
     var env = ProcessInfo.processInfo.environment
     env["SPOTIFY_ACCESS_TOKEN"] = token
     process.environment = env
     process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
     process.arguments = ["npm", "run", "dev"]
     ```

   - **Token logging hygiene**  
     Make sure we never log the full token:
     - Use `token.prefix(8)` or similar in logs.
     - Fix any logs that might print the entire token.

   - **Process lifecycle**  
     - `isRunning` should reflect `process?.isRunning`.
     - `stop()` should call `terminate()` (and optionally wait) and clear the stored `process`.
     - A `terminationHandler` (if present) should log and null out the process reference.
   
   - **Bundled mode stub**  
     If there is a `.bundled` or similar launch mode:
     - It should compile.
     - It’s okay if it just logs a TODO and returns for now, but it should **not** crash.

3. Add small, clear `print` logs if anything important is missing, e.g.:

   ```swift
   print("[InternalPlayerManager] Starting internal player in dev mode at \(localRepoURL.path)")
   print("[InternalPlayerManager] Using token prefix: \(token.prefix(8))…")
   print("[InternalPlayerManager] Process launched with PID \(process.processIdentifier)")
   print("[InternalPlayerManager] Stopping internal player (PID: \(process.processIdentifier))")
  ```

Keep it concise and consistent.

### Task 2 – Ensure there’s a simple debug UI to start/stop the internal player

If there is already a UI element wired up to start/stop the internal player using a real token, **validate it and only adjust it if necessary**.

If there is **no** such UI yet (or it’s buried / awkward), then:

1. Create a small, obviously “dev” SwiftUI view, for example `InternalPlayerDebugView`, somewhere reasonable like:

   * `Electric_Slideshow/Debug/InternalPlayerDebugView.swift`, or
   * Next to other debug or settings views.

2. This view should:

   * Have access to:

     * `SpotifyAuthService` (or whatever type can provide `getValidAccessToken()`).
     * `InternalPlayerManager` (or protocol injection via `InternalPlayerControlling`).

   * Show:

     * A “Start Internal Player” button.
     * A “Stop Internal Player” button.
     * A simple status text: “Internal Player Status: Running / Not Running”.

   * Behavior:

     * When “Start” is tapped:

       * Call `getValidAccessToken()` to obtain a token (using the existing auth service).
       * Call `internalPlayerManager.start(withAccessToken: token)`.
       * Handle errors by printing to console and optionally updating a small `errorMessage` string displayed in the view.
     * When “Stop” is tapped:

       * Call `internalPlayerManager.stop()`.

   * Keep styling minimal — this is a debug tool, not a polished user-facing setting.

3. Expose this debug view in some way that’s easy for me to reach in a dev build, for example:

   * A “Debug” section in your main navigation, or
   * A temporary entry in a sidebar / tab / menu.

   It’s fine if this is clearly dev-only; I can hide it later.

### Task 3 – Add a Markdown testing checklist

Create a new file in the repo root (or under `Docs/`) named:

* `INTERNAL_PLAYER_TESTING.md`

Populate it with a **clear, step-by-step manual testing guide** for me. It should include at least:

1. **Electron repo prep (one-time)**

   * `cd` into `electric-slideshow-internal-player`.
   * Run `npm install`.
   * Confirm that `npm run dev` works when run manually (Electron window opens).

2. **Swift app configuration (one-time)**

   * Edit `InternalPlayerManager.defaultDevRepoPath` to the actual absolute path to the Electron repo.
   * Ensure the Spotify app credentials and redirect URIs are configured correctly for the macOS app (you can mention this at a high level; no secrets).

3. **Running the integrated dev stack**

   * In Xcode, run `Electric Slideshow` in Debug.
   * Log into Spotify through the app if needed so that a valid token is available.

4. **Using the debug UI (InternalPlayerDebugView or equivalent)**

   * Navigate to the internal player debug UI.

   * Press “Start Internal Player”:

     * Expect Xcode console logs:

       * Internal player starting (dev mode).
       * Token prefix.
       * Process PID.
     * Expect the Electron dev window to appear.
     * In the Electron window, the internal player UI should show connected/initializing status.

   * Open the Spotify client (desktop or mobile), and:

     * Look for a device named “Electric Slideshow Internal Player” (or whatever name is configured in the Electron app).
     * Transfer playback to that device.
     * Confirm audio plays through the internal player environment (however you’ve configured sound output).

   * Press “Stop Internal Player”:

     * Expect the Electron window to close and logs indicating the process stopped.
     * Confirm that `isRunning` updates to false.

5. **App lifecycle check**

   * With the internal player running, quit Electric Slideshow entirely.
   * Confirm:

     * Electron window closes.
     * No stray Node/Electron processes remain (you can mention `Activity Monitor` or `ps`).
   * Re-launch Electric Slideshow and verify you can start the internal player again.

6. **Common failure modes**

   * If the Electron repo path is wrong:

     * Expected Swift log message.
   * If Spotify auth fails:

     * Expected message or error string in the debug UI.
   * If the internal player crashes:

     * What logs to look at (Xcode vs Electron terminal).

The goal of this doc is: if Future Me comes back in 3 months, I can follow `INTERNAL_PLAYER_TESTING.md` line-by-line and get the internal player working again.

---

## How to Respond

1. First, perform the sanity check and minimal code tweaks (Tasks 1 and 2).
2. Then create `INTERNAL_PLAYER_TESTING.md` with the manual testing instructions.
3. In your response, summarize:

   * Which files you inspected and changed.
   * The shape of the debug UI you added or validated.
   * The key steps from `INTERNAL_PLAYER_TESTING.md`.

Remember:

* Do **not** add tests.
* Do **not** introduce new, heavy abstractions.
* Keep changes minimal, explicit, and focused on testability and clarity.

---

## 2. How *you* test it (high-level checklist)

Once Roo has done the above and committed its changes (or you’ve reviewed them):

1. **Prep Electron once**
   - `cd /path/to/electric-slideshow-internal-player`
   - `npm install`
   - Optionally: run `npm run dev` manually once to make sure it launches.

2. **Set the dev path in Swift**
   - Open `InternalPlayerManager.swift` (or whatever it’s called).
   - Set `defaultDevRepoPath` to your actual path, e.g.:
     ```swift
     static let defaultDevRepoPath = "/Users/joshlevy/Projects/electric-slideshow-internal-player"
     ```
   - Build to make sure it compiles.

3. **Run Electric Slideshow (Xcode)**
   - Run the app in Debug.
   - Make sure your Spotify auth flow completes so `getValidAccessToken()` returns a real token.

4. **Open the internal player debug UI**
   - Whatever Roo created (e.g. `InternalPlayerDebugView`), navigate to it.
   - You should see:
     - Status text (“Not Running”).
     - Start/Stop buttons.

5. **Start the internal player**
   - Click “Start Internal Player”.
   - Watch Xcode console:
     - `[InternalPlayerManager] Starting internal player in dev mode at …`
     - `Using token prefix: …`
     - `Process launched with PID …`
   - A terminal window for `npm run dev` may open or log to the Xcode console only, depending on setup.
   - An Electron window from the internal player app should pop up.

6. **Verify Spotify device**
   - Open Spotify on your Mac or phone.
   - In the device list, look for “Electric Slideshow Internal Player” (or whatever you named it in the Electron renderer).
   - Transfer playback to that device.
   - Confirm audio plays.

7. **Stop the internal player**
   - Click “Stop Internal Player” in the debug UI.
   - Electron window should close.
   - Xcode console should show a “Stopping internal player” log.
   - Status flips to “Not Running.”

8. **Quit the app**
   - With internal player running, quit Electric Slideshow entirely.
   - Confirm Electron shuts down too (no stray processes in Activity Monitor).

If any step is weird (e.g. no Electron window, device not appearing, etc.), copy the relevant logs and we can debug the specific failure mode together.

That should give you exactly what you asked: a Roo prompt to audit + wire things cleanly, and a concrete path for you to prove the whole stack is behaving end-to-end.
::contentReference[oaicite:0]{index=0}

