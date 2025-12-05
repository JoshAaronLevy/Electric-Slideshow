# Music-Playback-Bug-Prompt

### Context & Problem

We’re working on the Electric Slideshow macOS SwiftUI app. Slideshows sync photo slides with Spotify playback. There are two playback backends:

* **External**: Spotify desktop app via Web API.
* **Internal**: an Electron app using the Spotify Web Playback SDK, selected via `PlaybackBackendFactory.defaultMode = .internalWebPlayer`.

**Bug:**
When using the **internal** backend (Electron/Web Playback SDK), starting a slideshow causes music to play for **less than a second per track** before skipping to the next track. This repeats across the playlist.

When using the **external** backend, the same slideshow + clip settings behave correctly: clip windows (30/45/60 seconds or full track) play as expected.

We already ran an analysis pass (you generated a Markdown report). That report identified several suspects in `SlideshowPlaybackViewModel`, especially around clip-timer logic and double re-arming.

Now I want you to **modify the code** to harden the clip-timing logic and stop the rapid skipping behavior for the internal backend **without breaking the external backend**.

### Do NOT write tests

* **Do NOT** create or modify any test files.
* **Do NOT** add or change unit tests, UI tests, or snapshot tests.
* This task is implementation + logging only.

---

### Key Observations from Your Previous Analysis (Use These)

From your prior report (reusing the important bits):

1. **Clip timer + double re-arm**

   * `startMusicClipTimer`’s timer callback:

     * calls `skipToNextTrack()`, and
     * calls `resetMusicClipTimerForCurrentTrack()`.
   * `skipToNextTrack()` *also* calls `resetMusicClipTimerForCurrentTrack()` when a backend exists.
   * This can result in **two back-to-back clip applications** per track.

2. **Zero / tiny clip windows**

   * `applyClipForCurrentTrack`:

     * fetches `/me/player`,
     * computes an `effectiveClipWindow`,
     * seeks to `startMs`,
     * then calls `startMusicClipTimer(durationSeconds: ...)`.
   * There is:

     * A possibility of `duration_ms == 0` or missing,
     * And for `.custom` clips, a min clip window (`minClipWindowMs`) set to **500 ms**.
   * That means:

     * For internal playback (where state can be more transient), we can end up creating clip windows that are effectively **0 or sub-second**, leading to immediate timer firing and rapid skips.

3. **No gating on “track is actually playing”**

   * Clip logic is armed immediately after `/me/player/play` and whenever URI changes.
   * There’s no explicit check that:

     * `is_playing == true`, and
     * `duration_ms > 0`
       before arming the timer.
   * With Web Playback SDK, early polls may show paused/buffering/partial state, which we shouldn’t use for clip timing.

We’ll treat these as the **primary causes** to address.

---

### Files to Modify

Please focus on (paths approximate from your earlier report):

* `Electric Slideshow/ViewModels/SlideshowPlaybackViewModel.swift`

  * Core slideshow + clip logic, timers, skip/advance, etc.
* If needed for minor logging / backend-type awareness (only if necessary and minimal):

  * `Services/SpotifyInternalPlaybackBackend.swift`
  * `Services/SpotifyExternalPlaybackBackend.swift`
  * `Services/PlaybackBackendFactory.swift`

But the bulk of the logic changes should live in **`SlideshowPlaybackViewModel.swift`**.

---

### Tasks / Requirements

#### 1. Fix the double re-arming of the clip timer

**Goal:** Ensure that for each track, the clip timer is armed **once**, and when it fires, the code advances to the next track and re-arms the clip timer **only once**, in a single, well-defined place.

Concretely:

1. Find `startMusicClipTimer` in `SlideshowPlaybackViewModel`.

   * It currently:

     * invalidates the old `musicClipTimer`,
     * creates a new one,
     * and in the timer callback:

       * calls `skipToNextTrack()`,
       * and then calls `resetMusicClipTimerForCurrentTrack()`.

2. Find `skipToNextTrack()` in `SlideshowPlaybackViewModel`.

   * It currently:

     * uses the backend to skip the track,
     * and also calls `resetMusicClipTimerForCurrentTrack()` when a backend exists.

**Change the behavior as follows:**

* **Single source of truth for re-arming**:

  * Choose **one** place where `resetMusicClipTimerForCurrentTrack()` is called after a successful track skip (I recommend keeping it in `skipToNextTrack()` and **removing it from the timer callback**).
  * The timer callback should:

    * log that the clip timer fired,
    * call `skipToNextTrack(reason: .clipEnded)` (or similar),
    * **NOT** directly call `resetMusicClipTimerForCurrentTrack()`.

* Ensure that:

  * `skipToNextTrack` only calls `resetMusicClipTimerForCurrentTrack()` **once** per successful skip.
  * There are no other hidden call sites that cause an immediate second re-apply.

Add some lightweight logging to make sure we can see:

* When `startMusicClipTimer` is invoked (with duration and reason).
* When the timer actually fires.
* When `skipToNextTrack` is invoked and from where (e.g., “fromClipTimer = true/false”).

(Keep logs concise; no spammy huge dumps.)

---

#### 2. Harden `applyClipForCurrentTrack` against zero / tiny durations

**Goal:** Never schedule a music clip timer with a duration that is obviously invalid (0, negative, or absurdly tiny), especially when using the internal backend.

In `SlideshowPlaybackViewModel.applyClipForCurrentTrack`:

1. After you fetch `/me/player` and compute the `effectiveClipWindow` (duration, startMs, endMs, etc.), add checks:

   * If `durationMs <= 0` (from the API) **or** the computed clip window in seconds is:

     * `<= 0`, or
     * `< 1.0` seconds (we’ll define a new safety minimum),

     then:

     * Log a warning with:

       * current backend type (internal/external if easily accessible),
       * track URI,
       * raw `duration_ms`,
       * computed clip window.
     * **Do NOT** call `startMusicClipTimer` for this track.
     * Instead, choose a safe fallback behavior. Options:

       * Either treat it as “full track, no enforced clip” (skip timer entirely, let user or Spotify move forward).
       * Or use a conservative default of something like 10 seconds for debugging.

   I’d suggest:

   ```swift
   let minSafeClipSeconds: Double = 1.0 // or slightly higher if you prefer

   guard durationMs > 0,
         clipWindowSeconds >= minSafeClipSeconds else {
       // log and bail out; no clip timer
       return
   }
   ```

2. For `.custom` clip windows:

   * Locate the logic that applies `minClipWindowMs` (currently ~500 ms).
   * Increase this minimum (e.g., 3,000–5,000 ms) so that even in the presence of slightly bad metadata, we don’t intentionally create 0.5s windows.
   * Alternatively (and probably better):

     * If custom start/end are invalid (end <= start or produce a window < `minSafeClipSeconds`), **fall back** to:

       * the playlist’s default clip mode, or
       * the global `musicClipMode` instead of forcing a 500 ms window.

   Implement this as cleanly as you can while preserving existing behavior for valid custom windows.

---

#### 3. Gate clip-timer arming on “track is actually playable”

**Goal:** Don’t arm the clip timer until we’re sure the player is in a sane state (track has a duration, and is actually playing or very close to playing).

Still in `applyClipForCurrentTrack`:

1. You already get `/me/player` and have `is_playing`, `item`, `duration_ms`, etc.

2. Add a guard before seeking and scheduling the timer that requires:

   * `durationMs > 0`, and
   * either:

     * `isPlaying == true`, or
     * `progress_ms` is at least at the seek start or very close.

   The idea is:

   ```swift
   guard durationMs > 0 else {
       // log and return
       return
   }

   // Optional but helpful: if !isPlaying, either bail or only proceed if this is expected.
   ```

3. If these conditions aren’t met (especially for the **internal** backend, where early polls may come back with incomplete data):

   * Log that clip application is being deferred because playback isn’t ready (include backend type).
   * Don’t schedule the timer in this pass; rely on the **next** `playbackCheckTimer` poll (when state stabilizes) to re-call `applyClipForCurrentTrack`.

You don’t need to introduce a super-complex state machine—just avoid arming a timer when the state is obviously bogus.

---

#### 4. Light logging for diagnostics (no overkill)

Add minimal, targeted logging in `SlideshowPlaybackViewModel`:

* When `startMusicClipTimer` is called:

  * log: track URI, clip duration, backend type, and “reason” if available.
* When the `musicClipTimer` fires:

  * log: track URI, backend type.
* When `skipToNextTrack` is called:

  * log: caller context (e.g., “fromClipTimer = true/false”), backend type.
* In `applyClipForCurrentTrack`:

  * log when you **do not** schedule a timer because of invalid duration / clip window / not-playing state (with key fields).

Make these logs easy to grep but not excessively verbose.

---

### Implementation Notes / Style

* Keep changes localized to `SlideshowPlaybackViewModel` as much as possible.
* If you need to know the backend type for logging, prefer:

  * simple, non-invasive ways (e.g., flag in the view model derived from `PlaybackBackendFactory`), and
  * don’t introduce a large dependency tangle between the view model and the backends.
* Make sure the **external backend behavior is unchanged** from the user’s perspective:

  * Clips should still play for their configured lengths as before.
  * The only difference should be more robust handling of edge cases and no rapid skipping.

---

### Acceptance Criteria

When you’re done, the code should satisfy:

1. **No more rapid skipping** with the internal backend:

   * Running a slideshow with the internal Electron/Web Playback SDK backend:

     * Each track should play roughly for its configured clip window (e.g., 30/45/60 seconds) or full track, **not** <1 second.
     * It should no longer burn through an entire playlist in a few seconds.

2. **External backend remains stable**:

   * With the external Spotify app backend selected:

     * Slideshow behavior should remain the same as before.
     * No regression in how clips are timed.

3. **Logging confirms sane behavior**:

   * Only one clip timer is armed per track.
   * Clip timers are never scheduled with obviously invalid or absurdly tiny durations.
   * When the timer fires, there is exactly one subsequent re-application of the clip for the next track (no double re-arm).

---

When you implement these changes, please:

* Show the updated Swift code (especially for the modified functions in `SlideshowPlaybackViewModel.swift`).
* Briefly summarize what you changed at the top of your response.