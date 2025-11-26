## High-Level Goal

* Add a **right-hand sidebar** that is visible **only in Now Playing**.
* Move the **existing slideshow + music controls** from the bottom bar into this sidebar.
* Keep all existing playback behavior intact by continuing to route controls through the `NowPlayingPlaybackBridge` and `SlideshowPlaybackViewModel`.
* Make the sidebar *look* like a polished media panel:

  * Slideshow controls
  * Music controls
  * Slideshow photo count
  * Current track info (title + artist, if available)
* Leave the bottom bar in the layout, but we can strip it down or leave it as a simple status bar for now.

No new behaviors (favorites, playlist switching, etc.) yet—just reorganizing and improving the presentation of what you already have.

---

## Architecture Principles (to keep it safe)

1. **Do not duplicate logic.**

   * All slideshow and music actions still go through `SlideshowPlaybackViewModel`.
   * The sidebar is just another UI surface that calls the **same bridge closures** (`goToPreviousSlide`, `togglePlayPause`, etc.).
2. **One source of truth for playback state.**

   * Slideshow state (current index, total slides, isPlaying) still lives in the view model.
   * Music state (current track info, isMusicPlaying) continues to be derived from Spotify playback responses in the view model.
   * The sidebar reads those via a *lightweight* bridge exposure—not its own independent state.
3. **Now Playing owns layout, not logic.**

   * `NowPlayingView` is where we change layout (add sidebar + adapt bottom bar).
   * `SlideshowPlaybackView` and `SlideshowPlaybackViewModel` stay focused on the actual slideshow/music behavior.

If we stick to these, the risk of regression is low.

---

## Stage 1 – Introduce the Sidebar Layout (Empty Shell)

**Goal:** Add the sidebar layout to `NowPlayingView` without moving controls yet.

### Changes

* In `NowPlayingView`, wrap the main content area in an `HStack`:

  * Left: `SlideshowPlaybackView` (as it is today)
  * Right: a new `NowPlayingSidebarView` (initially very simple / placeholder)

* Keep the `NowPlayingBottomBar` below this `HStack`, unchanged for the moment.

Conceptual layout:

```text
VStack
  HStack
    [ SlideshowPlaybackView ]  <-- fills remaining width
    [ NowPlayingSidebarView ]  <-- fixed width (e.g. 280–320 pt)
  [ NowPlayingBottomBar ]
```

### Sidebar behavior (for now)

* `NowPlayingSidebarView` receives:

  * The currently active `Slideshow?` (from `NowPlayingStore`)
  * Access to `NowPlayingPlaybackBridge` via `@EnvironmentObject`
* For Stage 1, it can simply show:

  * Slideshow title
  * A “Now Playing” label
  * Maybe some dummy content
* The point is to get the layout right, confirm performance and resizing feel good, and ensure it’s only visible in `.nowPlaying`.

**Risk:** Minimal—this is just layout scaffolding.

---

## Stage 2 – Move Controls from Bottom Bar → Sidebar

**Goal:** Move the actual slideshow and music buttons into the sidebar, but **keep using the same bridge closures** so behavior does not change.

### 2.1. Reuse `NowPlayingPlaybackBridge` actions

You already have something like:

* `goToPreviousSlide`
* `togglePlayPause`
* `goToNextSlide`
* `musicPreviousTrack`
* `musicTogglePlayPause`
* `musicNextTrack`

Currently, the bottom bar calls these.

The sidebar will:

* Import `@EnvironmentObject var playbackBridge: NowPlayingPlaybackBridge`
* Use those same closures for its buttons.

### 2.2. Sidebar control layout

Design-wise, something like:

* **Section 1: Slideshow**

  * Slideshow title
  * “Photo X of Y” (we’ll wire this up in Stage 3)
  * Slideshow controls in a horizontal row:

    * Previous slide
    * Play/Pause
    * Next slide
* **Section 2: Music**

  * “Now Playing”
  * Track title + artist (Stage 3)
  * Music transport controls:

    * Previous track
    * Play/Pause
    * Next track

Styling can be richer than the bottom bar:

* Rounded rectangles, subtle backgrounds, elevation, etc.
* Slightly larger icons, better spacing, maybe a vertical stack like a real Now Playing pane.

### 2.3. Bottom bar after the move

Once the controls are in the sidebar:

* `NowPlayingBottomBar` can be temporarily:

  * A super minimal status strip, or
  * A placeholder to be used later (e.g. for global progress or text status).
* For safety, you can:

  * Remove the buttons from the bottom bar, or
  * Leave them but visually de-emphasize them while you get used to the sidebar UX.

**Risk:** Still low, because we’re not touching the logic, just wiring the same closures from a different place.

---

## Stage 3 – Exposing Photo Count + Current Track to the Sidebar

**Goal:** Give the sidebar enough *read-only* data to display:

* “Photo X of Y”
* Current track title and (if available) artist

This is the only stage that touches model-ish code, so we keep it focused.

### 3.1. Decide where sidebar reads state from

We have two main options:

1. **Expose more properties via `NowPlayingPlaybackBridge`** (recommended)

   * Add `@Published` on the bridge like:

     * `currentSlideIndex`
     * `totalSlides`
     * `isSlideshowPlaying`
     * `currentTrackTitle`
     * `currentTrackArtist`
     * `isMusicPlaying`
   * Sidebar binds to these and redraws automatically when they change.
2. **Expose the view model directly** to Now Playing / sidebar (tighter coupling)

   * Pass `SlideshowPlaybackViewModel` up and down.
   * This makes the sidebar aware of internals we might want to keep encapsulated.

I’d recommend **#1** for now: keep the bridge as the “public surface” for what Now Playing needs to know.

### 3.2. Where those values come from

* `SlideshowPlaybackViewModel` already knows:

  * `currentIndex`
  * `images.count` or some equivalent
  * `isPlaying`
  * Current playback state / track info from Spotify (you likely already have a structure for that).
* In `SlideshowPlaybackView.onAppear` (where you already assign the closures to the bridge), you also:

  * Seed the bridge’s properties with the current values.
  * Subscribe to the view model’s `@Published` values and update the bridge as needed.

Conceptually:

* View model remains the **source of truth**.
* Bridge mirrors a subset for UI consumption.
* Sidebar just observes the bridge.

### 3.3. Sidebar reads the values

Once the bridge exposes:

* `currentSlideIndex`, `totalSlides`
* `currentTrackTitle`, `currentTrackArtist`
* `isSlideshowPlaying`, `isMusicPlaying`

Then `NowPlayingSidebarView` can:

* Render “Photo X of Y” as:

  * If 0-based: `currentSlideIndex + 1` of `totalSlides`
* Render track info as:

  * “Track Name – Artist Name”
  * Or show a graceful “No track playing” / “Music disabled” label when empty.

**Risk:** Moderate but controlled, since we’re adding read-only exposure of state we already have, and not changing control flow.

---

## Stage 4 – Visual Polish & Micro-Interactions

**Goal:** Make the sidebar feel like a sleek, intentional part of the app, not just a vertical bar with buttons.

Ideas (all purely visual; no new behavior):

* Use a slightly darker panel background than the main content, maybe with:

  * Rounded inner corners.
  * A subtle border or shadow.
* Highlight active play/pause state:

  * Change icon or background tint based on `isSlideshowPlaying` / `isMusicPlaying`.
* Add small labels above sections:

  * “Slideshow”
  * “Music”
* Add small separators (`Divider()`) between sections for visual grouping.
* Use SF Symbols that feel “media player”–like:

  * `backward.end.fill`, `play.fill`, `pause.fill`, `forward.end.fill` etc.

Because all of this is built on top of the bridge + view model, polish is basically “free” in terms of complexity.

---

## Why I like this plan

* **It gives you immediate UX payoff.**
  The app will feel more like a real media player: slideshow on the left, controls and info on the right.

* **It doesn’t change core behaviors.**
  We’re not rethinking how music starts, how slides advance, or how Now Playing is activated. We’re just re-housing the controls and exposing a bit more state.

* **It sets you up for the future.**
  Once the sidebar is in place and showing controls + photo count + track info, it becomes the natural home for:

  * Session playlist selection (later).
  * Favorites heart / quick actions.
  * Per-photo metadata.
  * Device selection or more detailed Spotify info.

If this feels good to you, the next step (when you’re ready) would be:

* Pick **Stage 1 + 2 together** (sidebar shell + moving controls), and I’ll turn that into a tightly scoped, file-by-file implementation guide with concrete code snippets.