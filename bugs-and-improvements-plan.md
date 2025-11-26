## Recommended Order of Implementation

### 1. **Now Playing: clean up in-photo controls + mouse interaction**

**Why first:**
This is low–medium risk, immediately improves the core “media app” feel, and simplifies the UX before we wire up more controls. It also removes legacy sheet-era behavior that’s now actively confusing.

**What this touches / context:**

* **`SlideshowPlaybackView`**

  * Currently:

    * Uses `showControls`, `controlsTimer`, and `onMouseActivity()` to show/hide the large overlay controls after 3 seconds of no mouse movement.
    * Shows a top bar with:

      * An **X button** (`dismiss()`) that used to close the sheet.
      * Progress text and slide counter.
    * Shows bottom overlay controls for:

      * Previous / play-pause / next slide.
      * Music controls (prev/next, pause, etc.) wired into `SlideshowPlaybackViewModel`.
  * Gestures:

    * **Spacebar** toggles slideshow play/pause via `viewModel.togglePlayPause()`.
    * Arrow keys move slides.
    * `.onContinuousHover` is used only to keep `showControls` alive.

* **What this item should accomplish conceptually:**

  * Remove the “hover to show big overlay” pattern (and the `X` in the top-left).
  * Remove the dismiss/escape behavior that conceptually belongs to a sheet, not the main Now Playing page.
  * Replace that paradigm with:

    * A simpler main image that:

      * On click, toggles play/pause of the slideshow (and eventually, the synced music – see item 2).
    * No “floating” controls over the photo that appear/disappear on hover. Controls should live in the **NowPlaying bottom bar** instead.
  * Keyboard shortcuts (space, arrows) can remain, but should conceptually match whatever the bottom bar does.

**Dependencies:**
Pretty self-contained in `SlideshowPlaybackView` and doesn’t require touching `NowPlayingView` or the bottom bar yet, aside from making sure we’re no longer depending on `dismiss()` / sheet behavior.

---

### 2. **Now Playing: sync slideshow play/pause with Spotify playback + paused visual state**

**Why second:**
Once the in-photo UX is simplified, the next critical behavior is that “the slideshow and the music feel like *one* experience.” Right now they’re independent: pausing the slideshow only stops the slide timer; music keeps going. That’s the biggest behavior mismatch with what you described.

**What this touches / context:**

* **`SlideshowPlaybackViewModel`**

  * Current behavior:

    * `startPlayback()`:

      * Loads images.
      * Calls `startMusic()` (if a playlist is linked).
      * Starts slide timer.
      * Starts playback state monitoring.
    * `togglePlayPause()`:

      * Only starts/stops the **slide timer** (`startSlideTimer()`, `stopSlideTimer()`).
      * Does not pause/resume Spotify.
    * Music control helpers:

      * `startMusic()` – finds playlist in `PlaylistsStore` and calls `spotifyAPIService.startPlayback(trackURIs:deviceId:)`.
      * `stopPlayback()` – stops slide timer, stops monitoring, and `await stopMusic()`.
      * `pausePlayback()` / `resumePlayback()` abstractions do **not** exist yet.
      * `skipToNextTrack()`, `skipToPreviousTrack()` delegate to `SpotifyAPIService`.

* **`SpotifyAPIService`**

  * Has:

    * `startPlayback(trackURIs:deviceId:)` – `PUT /me/player/play` with a body that sets the queue.
    * `pausePlayback()` – `PUT /me/player/pause`.
    * No dedicated “resume current playback” method, but Spotify supports `PUT /me/player/play` with an empty body to resume from where it left off.

* **Visual “paused” indication:**

  * Right now the only visual indication is the control overlay in `SlideshowPlaybackView`, which we’re about to remove.
  * There’s no dedicated pause icon overlay or paused state in Now Playing.

**What this item should accomplish conceptually:**

* When the slideshow is paused:

  * Stop the slide timer.
  * **Pause Spotify playback** (via `SpotifyAPIService.pausePlayback()`).
* When the slideshow is resumed:

  * Restart the slide timer.
  * **Resume Spotify playback** without resetting the playlist/position (likely via a new `resumePlayback()` method on `SpotifyAPIService`).
* Clicking on the photo / pressing spacebar should control **both** slideshow and music together.
* Add a clear paused indicator:

  * Either:

    * A play icon centered over the photo when paused, **or**
    * A more subtle indicator in the bottom bar (“Paused” + appropriate icon), or both.

**Dependencies:**

* Builds directly on item 1’s simplified interaction model.
* Will require small additions to `SpotifyAPIService` and corresponding calls from `SlideshowPlaybackViewModel`.
* Does **not** yet require the bottom bar to be wired; the behavior can be driven entirely from `SlideshowPlaybackView` interactions.

---

### 3. **Now Playing: make bottom bar slideshow controls functional**

**Why third:**
Once the underlying slideshow/music sync is correct, we can safely surface that behavior through the global Now Playing UI. This is where we make the app feel like a proper media app: the bottom bar becomes the canonical control surface.

**What this touches / context:**

* **`NowPlayingView`**

  * Currently:

    * Uses `nowPlayingStore.activeSlideshow` to decide whether to show:

      * `SlideshowPlaybackView(…)` **OR**
      * The empty state.
    * Renders a `bottomBar(for:)` where:

      * Left side has placeholder slideshow controls:

        * `Button` for previous slide (no action).
        * `Button` for play/pause (icon stubbed as `viewModel-like` but actually just static).
        * `Button` for next slide (no action).
      * These buttons don’t know about the `SlideshowPlaybackViewModel` at all.

* **`SlideshowPlaybackView`**

  * Owns its **own** `@StateObject SlideshowPlaybackViewModel`.
  * The bottom bar in `NowPlayingView` has no way to access that state or control it.

**What this item should accomplish conceptually:**

* The bottom bar slideshow controls should:

  * `Previous` → `viewModel.previousSlide()`
  * `Play/Pause` → `viewModel.togglePlayPause()` (which, after item 2, will also pause/resume Spotify)
  * `Next` → `viewModel.nextSlide()`
* The icons should reflect the real state (`isPlaying`, `hasNextSlide`, `hasPreviousSlide`) instead of being hardcoded.

**Architecturally important consideration (this is why it’s later in the order):**

Right now the view model is **owned inside** `SlideshowPlaybackView`. To make the bottom bar truly functional, we likely need to:

* Either:

  * Hoist `SlideshowPlaybackViewModel` up into `NowPlayingView` and pass it down as an `@ObservedObject`, so both the main image and bottom bar share the same instance, **or**
  * Introduce some kind of shared store (e.g., expand `NowPlayingStore` to also track playback state) and have the bottom bar act on that.

That refactor is a bit more invasive than items 1–2, which is why I’d do it after the underlying behavior is correct.

---

### 4. **Now Playing: make bottom bar music controls functional (without affecting slideshow)**

**Why fourth (but closely related to 3):**
Once slideshow controls in the bottom bar work and the model is lifted appropriately, music controls in the same bar become straightforward to wire up. They should feel totally independent from the slideshow timeline, which is a key UX requirement you specified.

**What this touches / context:**

* **`NowPlayingView.bottomBar(for:)`** (right-hand side section)

  * Currently:

    * Shows placeholder “No track playing / Spotify” text.
    * Has previous / play/pause / next music buttons that:

      * Have empty actions or comments like “// previous track (to be wired later)”.
    * No actual playback state or binding to `SlideshowPlaybackViewModel.currentPlaybackState`.

* **`SlideshowPlaybackViewModel`**

  * Already knows about:

    * `currentPlaybackState`.
    * `skipToNextTrack()`, `skipToPreviousTrack()`.
    * `pausePlayback()` / `resumePlayback()` once we add them in item 2.
  * Already has logic to periodically call `checkPlaybackState()`.

**What this item should accomplish conceptually:**

* Bottom bar music controls:

  * `Prev` → `viewModel.skipToPreviousTrack()`.
  * `Play/Pause` → `pausePlayback()` / `resumePlayback()` **for Spotify only**, without touching `isPlaying` or the slide timer.
  * `Next` → `viewModel.skipToNextTrack()`.
* The music controls must not:

  * Pause the slideshow.
  * Change slide index.
  * Reset slideshow progress.

**Separation of responsibilities:**

* “Photo click / spacebar / slideshow play button” → controls **both** slideshow + music together (per item 2).
* “Music controls in bottom bar” → control **only Spotify** (track navigation, pause, resume, volume) and leave `isPlaying` / slide timer untouched.

**Dependencies:**

* Depends on item 3 (we need the bottom bar structured around the shared playback view model).
* Uses the same shared model as slideshow controls, but works on the music-related methods only.

---

### 5. **Global button and clickable UX (hover + pointer cursor)**

**Why fifth:**
This is mostly visual polish and consistency. It’s important, but it doesn’t block core functionality. Also, after we stabilize the Now Playing behavior, it will be easier to apply a consistent styling layer without fighting ongoing logic changes.

**What this touches / context:**

* **Where interactive elements live:**

  * Nav bar buttons: `AppNavigationBar.navigationButton(for:)`.
  * Slideshow cards: `SlideshowCardView` (thumbnail card, play overlay button, edit/delete buttons).
  * Settings tiles/cards: likely in `SettingsDashboardView` and related settings views (tiles/buttons to open Spotify device sheet, etc.).
  * Music/UI lists and other “card-like” elements across `Views`.

* **Current behavior:**

  * `AppNavigationBar`:

    * Buttons are `.buttonStyle(.plain)` with background changes for the selected state only.
    * No hover state, no pointer cursor.
  * `SlideshowCardView`:

    * Has a hover effect that shows the circular play overlay when `isHovered` is true.
    * But there’s no consistent visual card hover (e.g., subtle shadow/border) and no pointer cursor for the entire card region.
  * Settings tiles:

    * Likely plain buttons or tap gestures with minimal or no hover feedback (we’d confirm via `SettingsDashboardView.swift`).

**What this item should accomplish conceptually:**

* Introduce a **consistent pattern** for:

  * Card hover → light shadow / border / scale.
  * Button hover → subtle background and pointer cursor.
  * All clearly “clickable” things:

    * Use `.contentShape(Rectangle())` where needed so the hover/click area matches the visual element.
    * Change to `NSCursor.pointingHand` on hover (on macOS) for buttons/cards.

* Implementation-wise (later):

  * This is a great fit for:

    * A reusable `HoverableCardStyle` or `InteractiveCardModifier`.
    * A `PointerInteractiveButtonStyle` (or a simple `ViewModifier`) applied to all major interactive elements.

**Dependencies:**

* Largely independent of the Now Playing logic.
* But easier to do once the views themselves are not being structurally refactored (especially `NowPlayingView` and any settings views).

---

## Summary of Priority

In plain language:

1. **Clean up the Now Playing slide view**: remove legacy overlay controls & X button, move to a “click-to-toggle” model for the photo.
2. **Make slideshow and Spotify playback feel unified**: pausing/resuming one pauses/resumes the other, and clearly show when things are paused.
3. **Wire the bottom bar slideshow controls to the real playback model** so the Now Playing bar is the main control surface.
4. **Wire the bottom bar music controls to Spotify only**, making sure they don’t mess with the slideshow timeline.
5. **Polish the interactive UX across the app** with consistent hover states and pointer cursors.

If you’re good with this ordering, tell me which **step(s)** you want to tackle first (you could, for example, group 1+2 together as “Now Playing behavior pass 1”), and I’ll give you concrete, file-specific implementation instructions for that group only.