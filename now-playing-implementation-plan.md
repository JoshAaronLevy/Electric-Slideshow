## Phase 1 – Introduce the “Now Playing” section & make it the default

**Goal:** App knows about a new section, “Now Playing”, and can navigate to it. It becomes the default on launch.

### Steps

1. **Extend your section enum**

   * Add a new case (e.g., `.nowPlaying`) to `AppSection`.
   * Give it a title `"Now Playing"` and the play icon name you want in the navbar.

2. **Update `AppNavigationBar`**

   * Add the new section to the `sections` array in `AppMainView` (or wherever you define it), and ensure it’s placed *to the left* of “Slideshows,” as per your UX requirement.
   * Confirm the navigation bar renders the icon + label correctly for the new section.

3. **Change the default selected section**

   * Right now, you default to `.slideshows`.
   * Change `@State private var selectedSection` to initialize as `.nowPlaying` so the user lands there on app open.

4. **Wire “Now Playing” into main content switch**

   * In `AppMainView`’s `switch selectedSection` block:

     * Add a case `.nowPlaying` which will eventually host the `NowPlayingView`.
   * For now, you can show a simple placeholder (e.g. “Now Playing Coming Soon”) while we wire the rest in later phases.

**Criteria satisfied (partially):**

* #1: New navbar entry for Now Playing.
* #8 (partially): Now Playing becomes the default view on launch.

---

## Phase 2 – Hoist and centralize playback state (slideshow + music)

**Goal:** Move slideshow playback state to a shared, app-level place so the same state can be used by both Now Playing and other views (e.g. Slideshows list).

### Steps

1. **Identify your current playback view model**

   * You likely have `SlideshowPlaybackViewModel` (or similar) that:

     * Tracks the current slideshow.
     * Handles timers / advancing slides.
     * Starts/stops Spotify playback via `SpotifyAPIService`.
   * Right now it probably lives *inside* `SlideshowPlaybackView` or is created in the sheet.

2. **Promote the playback model to `AppMainView`**

   * Create a single `@StateObject` instance in `AppMainView`:

     * This becomes your single source of truth for “what is currently playing”.

3. **Update `SlideshowPlaybackView` and future `NowPlayingView` to **accept** this model**

   * Instead of creating the view model internally, they should take it via initializer.
   * That way they’re all talking to the same shared state.

4. **Design the “player state” responsibilities**

   * Minimal requirements for this phase:

     * Hold a reference to the currently active slideshow (or `nil`).
     * Expose computed properties like `isPlaying`, `currentImage`, `currentSlideIndex`, `totalSlides`.
     * Handle starting/stopping playback when given a slideshow.
   * We won’t change the logic yet; just move the ownership.

**Criteria enabled:**

* This sets you up for #2, #3, #4, #5, #7, #8 (they all depend on shared Now Playing state).

---

## Phase 3 – Create the `NowPlayingView` layout (without hooks yet)

**Goal:** Build the basic UI for the Now Playing screen, using the shared playback model.

### Steps

1. **Create `NowPlayingView`**

   * This view will live in the main content area when `selectedSection == .nowPlaying`.
   * It should accept the shared playback view model (and any Spotify / playlist store you already inject into playback).

2. **Define the main content area**

   * The central area should:

     * Show the current slideshow image scaled to fit the available space while preserving aspect ratio.
     * If no slideshow is active, show the “no slideshow playing” empty state message (we’ll align styling with your existing empty states in a later sub-step).

3. **Decide on controls layout for v1**

   * To avoid complexity, I’d **go with your alternative (6)** for the first iteration:

     * A **bottom bar** that always stays visible.
     * Bottom bar contains:

       * Slideshow controls (play/pause, next/prev, slide index “3 / 24”).
       * Music controls (play/pause, skip, maybe track name).
     * Bar height matches the height of your top navbar (so the visual rhythm is consistent).

4. **Integrate the bar visually**

   * Design-wise:

     * Treat the bottom bar as part of the Now Playing view (inside the content area).
     * The slideshow image should fill the remaining space between navbar and bottom bar, scaled to fit.

5. **Empty state messaging**

   * When there is **no active slideshow**:

     * The main area shows a centered message:

       * “No slideshow is currently playing. Go to Slideshows to create or start one.”
     * Centered both horizontally and vertically.
     * Styled to match your existing “empty Slideshows” message (same font hierarchy, colors, etc.).
     * The bottom bar can either:

       * Be hidden when no slideshow is active, or
       * Be visible but disabled/greyed out. (We can decide in implementation; I’d lean toward hidden to avoid clutter.)

**Criteria addressed:**

* #3: Slideshow fills main content area, scaled to fit.
* #6: We’re explicitly choosing the “always-visible bottom bar” variant.
* #8a/b: Empty-state messaging handled in Now Playing main area.

---

## Phase 4 – Route “Play” from Slideshows list to Now Playing instead of sheet

**Goal:** Clicking play on a slideshow no longer opens a sheet or toggles full-screen; instead, it routes to Now Playing and starts that slideshow using the shared playback model.

### Steps

1. **Remove sheet-based playback**

   * In `SlideshowsListView`:

     * Remove `@State` used for `activeSlideshowForPlayback` (or equivalent).
     * Remove `.sheet(item: ...) { SlideshowPlaybackView(...) }`.
   * We’re retiring that sheet flow entirely per your requirement (#4).

2. **Introduce a callback or environment-based trigger**

   * `SlideshowsListView` needs a way to say: “Start this slideshow and navigate to Now Playing.”
   * Implementation options (we’ll pick one later):

     * A closure passed from `AppMainView`: `onPlaySlideshow(slideshow: Slideshow)`.
     * Or using an `EnvironmentObject` coordinator that exposes a method `start(slideshow:)` and sets the selected section.

3. **Wire the play button**

   * Update the play button in each slideshow card to:

     * Tell the shared playback model to start playing that slideshow.
     * Set `selectedSection = .nowPlaying` via the mechanism above (binding, coordinator, etc.).

4. **Ensure app does **not** toggle full-screen anymore**

   * If your old `SlideshowPlaybackView` had logic like `window.toggleFullScreen(nil)` in `.onAppear`, we’ll cut that:

     * Either remove it outright.
     * Or keep it only behind some future “full screen” button we’ll add later.
   * After this, clicking play:

     * Leaves window mode unchanged.
     * Routes to Now Playing view with the slideshow taking up the full content area.

**Criteria addressed:**

* #2a / #2b: Clicking Play routes to Now Playing and stops auto full-screen.
* #4a/b: Sheet is no longer used for slideshow playback.

---

## Phase 5 – Hook up slideshow & music controls in the bottom bar

**Goal:** Make the controls in Now Playing actually operate the slideshow and music, with the basic playback controls.

### Steps

1. **Connect slideshow controls**

   * Bottom bar should call into the playback view model for:

     * `play/pause`
     * `nextSlide()`
     * `previousSlide()`
   * Display:

     * Current slide index and total slides (e.g. “3 / 24”).

2. **Connect music controls**

   * Reuse existing logic from `SlideshowPlaybackView` that already interacts with `SpotifyAPIService`:

     * `play/pause` music.
     * `nextTrack()` if you support it.
   * Display:

     * Current track name / artist (you already show this on hover in the old slideshow overlay; we’ll surface the same info in the bottom bar).

3. **Auto-hide behavior (optional, can be deferred)**

   * Your acceptance criteria 5/6 give us an escape hatch:

     * If hover-based auto-hide is too complex right now, we keep the bar always visible.
   * I strongly recommend:

     * For this first pass: bottom bar is **always visible**.
     * Later: we can add hover/timer-based fading if you still want the “disappear after a few seconds” behavior.

**Criteria partially addressed:**

* #5a/b: Controls exist and operate; auto-hide may come later if we want.
* #6: Bottom bar is the single, shared place for both slideshow and music controls.

---

## Phase 6 – Navbar title reflects current slideshow name

**Goal:** When a slideshow is playing, the center title of the navbar is the slideshow name; when not, it shows a sensible default.

### Steps

1. **Expose current slideshow metadata from the playback model**

   * At minimum:

     * `currentSlideshowName` (string or `nil`).
   * Might also be useful for the future (but not necessary yet):

     * `currentSlideshowId`, `isPlaying`, etc.

2. **Teach `AppMainView` to derive the navbar title**

   * For `.nowPlaying`:

     * If there’s an active slideshow → use its name.
     * Else → use a default like “Now Playing”.
   * For other sections:

     * Keep the existing `selectedSection.title`.

3. **Pass the computed title into `AppNavigationBar`**

   * Instead of always giving `selectedSection.title`, you pass:

     * `currentSectionTitle: computedTitleBasedOnSectionAndPlayback`.

4. **Center the title**

   * Ensure `AppNavigationBar` layout centers the title in the navbar regardless of which section is selected.
   * This might already be the case; if not, we’ll adjust constraints/layout when we do the code pass.

**Criteria addressed:**

* #7: Navbar title shows current slideshow name and is centered.

---

## Phase 7 – Polish the empty-state UX in Now Playing

**Goal:** Make the Now Playing “no slideshow” state feel consistent with the rest of the app.

### Steps

1. **Review existing empty states**

   * Look at how your Slideshows view renders the “no slideshows yet” message:

     * Typography (font size, weight).
     * Color scheme.
     * Spacing & layout.
     * Any icons used.

2. **Match that style in Now Playing**

   * Style the “No slideshow is currently playing” message to match:

     * Same font sizes & colors.
     * Same icon treatment, if any.
     * Same container feel (maybe a rounded card, or just centered text).

3. **Centering**

   * Ensure the message is centered:

     * Horizontally and vertically in the content area (excluding navbar and bottom bar).
   * This will likely be a `VStack` inside a `GeometryReader` or `frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)` – but we’ll sort details at code time.

**Criteria addressed:**

* #8b(i)/(ii): Proper empty-state message & styling.

---

## Phase 8 – Sanity checks & regression testing

Once the above phases are implemented, we’ll do a pass to make sure:

* Clicking **Play** on a slideshow:

  * Does *not* open a sheet.
  * Does *not* toggle the app into full-screen.
  * Immediately routes to Now Playing.
  * Starts the selected slideshow & music (assuming Spotify device is valid).

* Navigating between sections:

  * Leaves slideshow/music state intact (until you explicitly stop it).
  * Navbar title updates as expected.

* On app launch:

  * Now Playing is shown by default.
  * If no slideshow is active → you see the empty-state message.
  * If we later add persistence of playback state, Now Playing can restore where you left off.