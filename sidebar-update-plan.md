## Stage 1 – Clarify Visual Hierarchy & Grouping

**Goal:** Make it obvious what’s “the slideshow”, what’s “the music”, and what’s “controls vs info” at a glance.

**Key ideas:**

* **Section headings:**

  * Keep two sections: **SLIDESHOW** and **MUSIC**.
  * Make headings small, all caps, slightly muted (think Apple’s sidebar section labels).
* **Section grouping:**

  * Within each section, group:

    * Title + metadata (static info)
    * Playback controls (interactive)
  * Add consistent vertical spacing between groups so it reads like:

    ```
    SLIDESHOW
    [Title + “Photo X of Y”]
    [Slideshow transport controls]

    ─────────── divider ───────────

    MUSIC
    [Track title – artist]
    [Clip length control]
    [Music transport controls]
    ```
* **Typography tweaks:**

  * Slideshow title slightly larger / bolder than everything else.
  * “Photo 3 of 39” is quieter, almost caption-like.
  * Track title a bit stronger than artist.

**Files to touch later:**

* `NowPlayingSidebarView` (layout and text)
* Possibly a small `SidebarSectionHeader` view for reuse

---

## Stage 2 – Redesign the Playback Controls Cluster

**Goal:** Make the controls feel like a *media transport* instead of form buttons, and unify slideshow + music controls visually.

**Key ideas:**

* **Single “transport” concept:**

  * For slideshow:

    * A row: `[◀︎]  [big ▶︎ / ❚❚]  [▶︎]`
  * For music:

    * A row: `[⏮]  [▶︎ / ❚❚]  [⏭]`
  * Visually similar, but slideshow row is primary.
* **Primary vs secondary:**

  * Slideshow controls: larger icons / buttons.
  * Music controls: slightly smaller, or lighter styling.
* **Play/Pause emphasis:**

  * Center play/pause button is visibly the “main” control.
  * Slightly larger, maybe a filled background, while prev/next are more minimal.
* **Layout consistency:**

  * Both clusters align left and use the same spacing.
  * Vertical spacing between slideshow and music clusters is consistent and intentional.

**Files to touch later:**

* `NowPlayingSidebarView` (button layout)
* Possibly introduce mini helper views like `TransportControlsView` to avoid duplication.

---

## Stage 3 – Add “Alive” States & Feedback

**Goal:** The sidebar should *visually acknowledge* when things are playing vs paused, and which controls are usable.

**Key ideas:**

* **Play state feedback:**

  * When the slideshow is playing:

    * Play button shows **pause** icon.
    * Button style is “active” (stronger background, maybe blue or bright).
  * When paused:

    * Play button shows **play** icon.
    * Style is calmer.
* **Music state feedback:**

  * When music is playing:

    * Track title row subtly brightens or gains a tiny “playing” indicator (e.g. simple equalizer glyph).
  * When paused:

    * Returns to neutral state.
* **Disabled states:**

  * If `hasPreviousSlide` is false, previous button is clearly disabled.
  * Same for `hasNextSlide`.
* **Hover states (for sidebar only):**

  * Buttons get a mild hover highlight:

    * Slight background tint
    * Cursor becomes pointing hand
  * No over-the-top animation; just enough to feel responsive.

**Files to touch later:**

* `NowPlayingSidebarView` (state-driven styling)
* `NowPlayingPlaybackBridge` (you already expose `isSlideshowPlaying`, `isMusicPlaying`, etc.)

---

## Stage 4 – Make the Clip Length Selector Feel Intentional

**Goal:** The clip length control should look like part of the media experience, not a random settings dropdown.

**Key ideas:**

* **Label & layout:**

  * Keep a small label (“Clip length”) above or to the left of the control.
  * Align it with the music controls cluster so eye flow is:

    * [Track title]
    * [Clip length control]
    * [Music transport controls]
* **Visual integration:**

  * Use a style that matches the rest of the sidebar:

    * If everything else is flat, keep it flat but clearly interactive.
  * Ensure the dropdown width is tight to its content (not spanning too wide).
* **Optional micro-copy improvement:**

  * If you want later, we can change options from:

    * “30 seconds / 60 seconds / Full song”
    * To something more evocative like “Short / Medium / Full song” with tooltips.
  * For now, keep the text literal but laid out nicely.

**Files to touch later:**

* `NowPlayingSidebarView` (the Picker / SegmentedControl layout)

---

## Stage 5 – Polish the Bottom Bar & Overall Alignment

**Goal:** Make the bottom bar and the sidebar feel like part of one consistent “Now Playing” experience.

**Key ideas:**

* **Bottom bar role:**

  * Decide if the bottom bar is:

    * A **status strip** (“Now Playing: Grayson – Here Comes The Sun”), or
    * A minimal hint (“Playback controls are in the sidebar →”).
  * Whichever it is, align its text tone with the sidebar.
* **Alignment & spacing:**

  * Ensure the sidebar:

    * Has consistent horizontal padding from the right edge.
    * Aligns its heading, text, and buttons on an invisible vertical grid.
  * Make sure the bottom bar text aligns visually with the sidebar’s main column (even though it’s at the bottom).

**Files to touch later:**

* `NowPlayingBottomBar`
* Possibly `NowPlayingView` for padding/alignment tweaks

---

## Stage 6 – Theming & Reuse Clean-up

**Goal:** Make sure the new look is maintainable and consistent with the rest of the app.

**Key ideas:**

* **Extract reusable styles:**

  * A small “sidebar label” style for section headers.
  * A “primary transport button” style vs “secondary transport button” style.
* **Color tokens:**

  * Confirm you’re using app-level colors (e.g. `Color.appBlue`, etc.) so the sidebar matches the rest of Electric Slideshow.
* **Consistency pass:**

  * Make sure similar controls in Settings / Slideshows view use the same hover/active rules when appropriate.

**Files to touch later:**

* A shared style file (e.g. `AppTheme.swift` or `SidebarStyles.swift`)
* Minor adjustments back in `NowPlayingSidebarView` to use the helpers

---

### How I’d implement this with you, step-by-step

Once you’re happy with this plan, I’d suggest we:

1. Start with **Stage 1 + Stage 2 together** (hierarchy + playback cluster) – this will give you the biggest visual jump.
2. Then do **Stage 3** (alive states & feedback).
3. Then tidy up with **Stage 4–6** as smaller follow-ups.