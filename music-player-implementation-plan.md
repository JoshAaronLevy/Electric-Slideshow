# Internal Spotify Player – Implementation Plan

**Decision summary (Stage 0)**

* Playback stack: **Spotify Web Playback SDK** running inside a macOS `WKWebView`.
* Product scope: **personal / hobby** app. No commercial shipping.
* Spotify account: **Premium required**.
* UX:

  * Default to **internal player**.
  * Allow users to pick macOS output device via system audio (system volume/AirPlay), not a separate in-app device picker.
  * Support **scrubbing** and **basic volume control** in the UI.
  * No user-visible “internal vs external” mode switch; external remains only as an internal fallback.

---

## Stage 1 – Define a Playback Backend Abstraction

**Objective:** Decouple slideshow logic from how music is played, so we can plug in the Web Playback SDK without rewriting `SlideshowPlaybackViewModel`.

### 1.1 Identify current responsibilities

Mac app:

* `SpotifyAPIService` – calls backend REST endpoints (`play`, `pause`, `next`, `previous`, etc.).
* `SpotifyAuthService` – handles tokens for backend calls.
* `SlideshowPlaybackViewModel` – decides:

  * When to start a track.
  * Clip lengths and random offsets.
  * When to skip to next track.
* `NowPlayingPlaybackBridge` – exposes music state to the UI.

Node backend:

* Playback endpoints (e.g. `POST /spotify/play`, `/pause`, `/next`, `/previous`, `/seek`).
* Current assumption that playback happens on some Spotify Connect device (often Spotify.app).

### 1.2 Define a common playback interface

On the **macOS side**, design a Swift protocol (mentally for now):

* **Commands:**

  ```swift
  playTrack(id: String, offsetMs: Int?)
  pause()
  resume()
  nextTrack()
  previousTrack()
  seek(to positionMs: Int)
  setVolume(_ value: Double) // 0.0–1.0, optional initially
  ```

* **State callback / stream:**

  ```swift
  struct PlaybackState {
      let trackId: String?
      let trackName: String?
      let artistName: String?
      let positionMs: Int
      let durationMs: Int
      let isPlaying: Bool
      let isBuffering: Bool
  }
  ```

  Plus a way to subscribe:

  ```swift
  var onStateChanged: ((PlaybackState) -> Void)?
  var onError: ((PlaybackError) -> Void)?
  ```

### 1.3 Plan the implementations

Eventual implementations:

* `SpotifyExternalPlaybackBackend`

  * Uses current Node endpoints (existing behavior).
  * Will become **fallback** only.
* `SpotifyInternalPlaybackBackend`

  * Wraps a `WKWebView` + Web Playback SDK.
  * Will be the **primary** backend.

`SlideshowPlaybackViewModel` will:

* Only depend on `MusicPlaybackBackend` + `PlaybackState`.
* Be ignorant of *how* playback happens.

---

## Stage 2 – Adapt Current External Integration to the Backend Interface

**Objective:** Make existing behavior go through the new abstraction, but keep using the current backend + external device.

### 2.1 Implement `SpotifyExternalPlaybackBackend`

* Wrap `SpotifyAPIService` so that:

  * `playTrack` → your existing “start playlist / resume playlist” endpoints.
  * `pause`, `resume`, `nextTrack`, `previousTrack`, `seek` map to current REST calls.
* Poll or fetch playback state from existing endpoints (or add one if needed) and normalize into `PlaybackState`.

  * Short-term: polling timer (e.g. every 1–2 seconds).
  * Long-term: consider server-sent events / websockets (optional).

### 2.2 Change slideshow engine to use the backend

* In `SlideshowPlaybackViewModel`:

  * Replace direct calls to `SpotifyAPIService` with calls to a `MusicPlaybackBackend` instance.
  * Update the model’s own internal state from `PlaybackState` provided by the backend, not from ad-hoc responses.
* In `NowPlayingPlaybackBridge`:

  * Consume `PlaybackState` instead of bespoke properties where possible:

    * `isMusicPlaying`
    * `currentTrackTitle`, `currentTrackArtist`
    * `trackDurationMs` (for future scrubbing).

### 2.3 Preserve current user experience

* Verify:

  * Starting a slideshow still kicks off playlist playback.
  * Clip lengths (30/45/60/full) still behave as before.
  * Sidebar UI remains accurate.

At the end of Stage 2, **nothing looks different** to you as a user, but the macOS app talks to music through `MusicPlaybackBackend`.

---

## Stage 3 – Design the Internal Player Module (WKWebView + Web Playback SDK)

**Objective:** Design the shape of the internal player that wraps the Web Playback SDK inside a `WKWebView`.

### 3.1 Layered architecture

* **Swift / macOS:**

  * `InternalSpotifyPlayer`:

    * Owns a `WKWebView`.
    * Loads a local `internal_player.html` (bundled resource).
    * Exposes methods like:

      * `initialize(token: String)`
      * `playTrack(id: String, offsetMs: Int?)`
      * `pause`, `resume`, `next`, `previous`, `seek`, `setVolume`.
    * Implements `WKScriptMessageHandler` for `"playerEvent"` messages from JS.

  * `SpotifyInternalPlaybackBackend`:

    * Implements `MusicPlaybackBackend`.
    * Delegates to `InternalSpotifyPlayer`.
    * Translates JS events into `PlaybackState`.

* **Node backend:**

  * Endpoint: `GET /spotify/player-token`

    * Returns a Spotify access token with scopes for Web Playback SDK (`streaming`, `user-read-playback-state`, `user-modify-playback-state`, etc.).
  * Optionally: `POST /spotify/refresh-token` or reuse existing token refresh flows.

* **JS / HTML (loaded in WKWebView):**

  * Local resource `internal_player.html`:

    * Loads the Web Playback SDK script.
    * On page load:

      * Exposes JS functions for Swift to call (`playerInit`, `playerPlayTrack`, etc.).
    * Listens to `Spotify.Player` events and forwards them to Swift via `webkit.messageHandlers.playerEvent.postMessage(...)`.

### 3.2 Message design

* **Swift → JS:**

  ```js
  playerInit(accessToken)
  playerPlayTrack(spotifyTrackUri, offsetMs)
  playerPause()
  playerResume()
  playerNext()
  playerPrevious()
  playerSeek(positionMs)
  playerSetVolume(volume) // 0–1
  ```

* **JS → Swift (`playerEvent` messages):**

  ```json
  {
    "type": "stateChanged",
    "trackId": "...",
    "trackName": "...",
    "artistName": "...",
    "positionMs": 12345,
    "durationMs": 200000,
    "isPlaying": true,
    "isBuffering": false
  }
  ```

  And on error:

  ```json
  {
    "type": "error",
    "message": "Token expired",
    "code": "TOKEN_EXPIRED"
  }
  ```

This design doc can live in your repo as a separate `INTERNAL_PLAYER_DESIGN.md`.

---

## Stage 4 – Implement Skeleton Internal Player (No Real Audio Yet)

**Objective:** Get the plumbing in place: `WKWebView`, message passing, and backend class stubs, without worrying about actual Spotify playback.

### 4.1 Add `InternalSpotifyPlayer` (Swift)

* Create a new Swift file `InternalSpotifyPlayer.swift` in `Services` or a similar folder.
* Responsibilities:

  * Initialize a hidden or off-screen `WKWebView`.
  * Load `internal_player.html` from the app bundle.
  * Register a `WKScriptMessageHandler` for `"playerEvent"`.
  * Provide stub implementations for:

    * `initialize()`, `playTrack`, `pause`, `resume`, `nextTrack`, `previousTrack`, `seek`, `setVolume`.
  * For now, just `print` calls and accept incoming messages.

### 4.2 Add `SpotifyInternalPlaybackBackend` (Swift)

* Conforms to `MusicPlaybackBackend`.
* Delegates commands to `InternalSpotifyPlayer`.
* On receiving events from `InternalSpotifyPlayer`, converts them into `PlaybackState` and calls `onStateChanged`.

### 4.3 Wire backend selection

* Create a `PlaybackBackendFactory` (or simple init logic) that:

  * Always **prefers `SpotifyInternalPlaybackBackend`**.
  * If initialization fails (e.g., can’t load HTML, token endpoint unreachable), logs the error and instantiates `SpotifyExternalPlaybackBackend` as a fallback.
* `SlideshowPlaybackViewModel` gets its backend from this factory.

At the end of Stage 4, the internal backend compiles, gets instantiated, and you can see debug logs for calls and placeholder `playerEvent` messages—but no real Spotify playback yet.

---

## Stage 5 – Hook Up the Real Spotify Web Playback SDK

**Objective:** Make the internal player actually play audio via Spotify, using the Web Playback SDK and your Node backend.

### 5.1 Backend token endpoint

* Implement `GET /spotify/player-token`:

  * Takes the user’s existing stored refresh token / auth info.
  * Returns a **fresh access token** suitable for the Web Playback SDK.
  * Include token expiry info so the macOS app can request a new token when needed.

* Optional: add basic logging on the server for:

  * Requests to `/spotify/player-token`.
  * Token generation/refresh errors.

### 5.2 Implement `internal_player.html` + JS

* Bundle an HTML file with:

  * `<script src="https://sdk.scdn.co/spotify-player.js"></script>`
  * A script that:

    * Defines the functions Swift will call (`playerInit`, `playerPlayTrack`, etc.).
    * On `playerInit(token)`:

      * Creates a `Spotify.Player` instance with the provided token.
      * Sets up listeners for `ready`, `not_ready`, `player_state_changed`.
    * On play/pause/seek/next/previous commands:

      * Uses the SDK methods (`player.resume()`, `player.pause()`, etc.).
    * On `player_state_changed`:

      * Builds the JSON payload and posts to Swift via `webkit.messageHandlers.playerEvent.postMessage`.

### 5.3 Connect Swift to JS

* In `InternalSpotifyPlayer`:

  * On initialization:

    * Fetch a token from `/spotify/player-token` via your backend.
    * Inject JS call `playerInit("<token>")` into the webview with `evaluateJavaScript`.
  * Wire methods:

    * `playTrack` → `evaluateJavaScript("playerPlayTrack('\(uri)', \(offsetMs ?? 0))")`
    * `pause` → `playerPause()`
    * `resume` → `playerResume()`
    * etc.

* On receiving `"ready"` from JS:

  * Mark the internal backend as **active**.

* On `"error"` from JS:

  * Log and, if unrecoverable, fall back to `SpotifyExternalPlaybackBackend`.

At the end of Stage 5, in a happy-path scenario, Electric Slideshow can play Spotify audio internally using the Web Playback SDK.

---

## Stage 6 – Integrate Clip Modes, Random Offsets, and Scrubbing

**Objective:** Ensure internal playback behaves the same (and better) than the current external approach, including your 30s/45s/60s/full modes and user scrubbing.

### 6.1 Keep clip logic in `SlideshowPlaybackViewModel`

* `SlideshowPlaybackViewModel` remains in charge of:

  * Translating the chosen `MusicClipMode` (30s/45s/60s/full) into:

    * A random start offset (`offsetMs`) when applicable.
    * A clip duration (`clipLengthMs`).
  * Starting a track via `backend.playTrack(id, offsetMs)`.
  * Scheduling an automatic `nextTrack()` call after `clipLengthMs`.

* The backend doesn’t know about clip modes; it just plays tracks and reports state.

### 6.2 Scrubbing with internal playback

* Add scrubbing support to the UI:

  * Expose `currentPositionMs` and `durationMs` from `PlaybackState` via `NowPlayingPlaybackBridge`.
  * Add a slider in the music section:

    * Dragging the slider calls `backend.seek(to: newPositionMs)`.
    * When user releases the slider thumb, call `seek()`.

* For external backend:

  * Implement `seek()` only if the existing backend supports it (or simply disable the slider when using fallback).

### 6.3 Alignment with external fallback

* Ensure the slideshow logic:

  * Works identically whether the active backend is internal or external.
  * Always uses backend-agnostic timing (clip lengths, random offsets, etc.)

At the end of Stage 6, the **experience** should be:

* The same clip modes you have today, but powered by an internal player.
* Scrubbing works for internal playback.
* External fallback still works, just without scrubbing if the API doesn’t support it.

---

## Stage 7 – Volume Control, Output, and Error Resilience

**Objective:** Add nice-to-have controls and ensure the app is robust when the internal player misbehaves.

### 7.1 Volume

* Add a volume slider in the MUSIC section:

  * `backend.setVolume(value)`:

    * For internal backend, calls Web Playback SDK’s `setVolume`.
    * For external fallback, either:

      * No-op (and hide/disable slider), **or**
      * Map to an API if your backend supports volume.

* Optionally store per-slideshow preferred volume in your `SlideshowSettings`.

### 7.2 Output device semantics

* Rely on macOS system audio routing:

  * Web Playback SDK audio in `WKWebView` will go wherever the system’s output device goes (Speakers, AirPods, AirPlay, etc.).
  * No extra code needed for basic device selection; user can pick output in Control Center.

* (Optional) Surfacing basic info:

  * If Web Playback SDK exposes the device name, show a small label:

    * `Output: Electric Slideshow (internal player)`

### 7.3 Error handling and fallback

* In `SpotifyInternalPlaybackBackend`:

  * Detect fatal errors (token expiration that can’t be refreshed, SDK initialization failure, etc.).
  * When unrecoverable:

    * Notify the user with a subtle in-app message (e.g., toast or banner).
    * Switch to `SpotifyExternalPlaybackBackend`.
    * Continue slideshow & clip logic without crashing.

* Keep a log for debugging:

  * Internal: print statements or a rolling in-memory log.
  * Optional: log to disk in a simple text file for later inspection.

---

## Stage 8 – Cleanup, Docs & Future-Proofing

**Objective:** Make the new architecture understandable and easy to extend.

### 8.1 Code cleanup

* Remove dead code paths in `SpotifyAPIService` that are no longer used.
* Group playback-related code into a clear folder structure:

  * `/Services/Playback` (backends, internal player, etc.).
* Extract constant strings / URLs into configuration constants.

### 8.2 Documentation

* Add a `PLAYBACK_ARCHITECTURE.md` that:

  * Describes `MusicPlaybackBackend` and its implementations.
  * Describes the token flow and how to debug common issues.
  * Explicitly states:

    * **Premium required.**
    * Intended for **personal/hobby use**, not commercial distribution.

### 8.3 Future enhancements (optional ideas)

* Smooth crossfades between tracks when using internal player.
* “Smart shuffle” or “favs only” mode, controlled from the app.
* A future “local audio” backend that uses locally stored MP3/FLAC files and never touches Spotify.

---

This version bakes in your decisions:

* Web Playback SDK in `WKWebView`.
* Internal player as the default.
* External backend only as an **automatic, invisible fallback**.
* Scrubbing + basic volume as first-class UX.